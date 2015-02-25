-module(webcam_stream).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

-record(state, {port}).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/6,
         devices/0,
         start/6,
         start/0,
         stop/0]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------
start_link(Video, Audio, VBitrate, ABitrate, Height, Endpoint) ->
    List = [Video, Audio, VBitrate, ABitrate, Height, Endpoint],
    gen_server:start_link({local, ?SERVER}, ?MODULE, List, []).

start() ->
    io:format("webcam_stream:start(VideoChannel, AudioChannel, VideoBitrate, "
              "AudioBitrate, Height, RTMPEndpoint)~n").

start(Video, Audio, VBitrate, ABitrate, Height, Endpoint) ->
    List = [Video, Audio, VBitrate, ABitrate, Height, Endpoint],
    supervisor:start_child(webcam_stream_sup, List).

stop() ->
    gen_server:call(?SERVER, stop).

devices() ->
    Cmd = "ffmpeg -f avfoundation -list_devices true -i \"\" 2>&1 | awk -f priv/devices.awk",
    Devices = os:cmd(Cmd),
    re:split(Devices, "\n", [{return, list}, trim]).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------
init([Video, Audio, VBitrate, ABitrate, Height, Endpoint]) ->
    Cmd = "ffmpeg -f avfoundation -i \"" ++ integer_to_list(Video) ++ ":" ++
          integer_to_list(Audio) ++ "\" -c:v libx264 -b:v " ++
          integer_to_list(VBitrate) ++ "k -vf scale=-1:" ++ integer_to_list(Height) ++
          " -c:a libfdk_aac -b:a " ++ integer_to_list(ABitrate) ++ "k -f flv "++
          Endpoint,
    error_logger:info_msg("Starting ffmpeg: ~p~n", [Cmd]),
    Port = erlang:open_port({spawn, Cmd}, [exit_status]),
    State = #state{port = Port},
    {ok, State}.

handle_call(stop, _From, #state{port=Port}=State) ->
    {os_pid, Pid} = erlang:port_info(Port, os_pid),
    os:cmd("kill -9 " ++ integer_to_list(Pid)),
    {stop, normal, ok, State};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({Port, {exit_status, _}}, #state{port=Port}=State) ->
    {stop, exited, State}; 
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------


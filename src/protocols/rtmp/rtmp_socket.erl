-module(rtmp_socket).
-author(max@maxidoors.ru).
-include("../include/rtmp.hrl").
-include("../include/rtmp_private.hrl").
-include("../include/debug.hrl").

-export([accept/1, client_buffer/1, window_size/1, setopts/2, send/2]).
-export([status/3, status/4, invoke/2, invoke/4]).


%% gen_fsm callbacks
-export([init/1, handle_event/3,
         handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).

-export([wait_for_socket/2, loop/2]).


-spec(accept(Socket::port()) -> RTMPSocket::pid()).
accept(Socket) ->
  {ok, Pid} = gen_fsm:start_link(?MODULE, [self()], []),
  gen_tcp:controlling_process(Socket, Pid),
  gen_fsm:send_event(Pid, {socket, Socket}),
  {ok, Pid}.
  

-spec(client_buffer(RTMP::rtmp_socket_pid()) -> integer()).
client_buffer(RTMP) ->
  gen_fsm:sync_send_event(RTMP, client_buffer, ?RTMP_TIMEOUT).

-spec(window_size(RTMP::rtmp_socket_pid()) -> integer()).
window_size(RTMP) ->
  gen_fsm:sync_send_event(RTMP, window_size, ?RTMP_TIMEOUT).
  
% Func: setopts/2
%  Available options:
%  chunk_size
%  window_size
%  amf_version
-spec(setopts(RTMP::rtmp_socket_pid(), Options::[{Key::atom(), Value::any()}]) -> ok).
setopts(RTMP, Options) ->
  gen_fsm:send_event(RTMP, {setopts, Options}).

  
-spec(send(RTMP::rtmp_socket_pid(), Message::rtmp_message()) -> ok).
send(RTMP, Message) ->
  RTMP ! Message,
  ok.
  

-spec(status(RTMP::rtmp_socket_pid(), StreamId::integer(), Code::string()) -> ok).
status(RTMP, StreamId, Code) when is_list(Code)->
  status(RTMP, StreamId, list_to_binary(Code), <<"-">>).


-spec(status(RTMP::rtmp_socket_pid(), StreamId::integer(), Code::string(), Description::string()) -> ok).
status(RTMP, StreamId, Code, Description) when is_list(Code)->
  status(RTMP, StreamId, list_to_binary(Code), Description);

status(RTMP, StreamId, Code, Description) when is_list(Description)->
  status(RTMP, StreamId, Code, list_to_binary(Description));
  
  
status(RTMP, StreamId, Code, Description) ->
  Arg = {object, [
    {code, Code}, 
    {level, <<"status">>}, 
    {description, Description}
  ]},
  invoke(RTMP, StreamId, onStatus, [Arg]).
  
invoke(RTMP, StreamId, Command, Args) ->
  AMF = #amf{
      command = Command,
        type = invoke,
        id = 0,
        stream_id = StreamId,
        args = [null | Args ]},
  send(RTMP, #rtmp_message{stream_id = StreamId, type = invoke, body = AMF}).

invoke(RTMP, #amf{stream_id = StreamId} = AMF) ->
  send(RTMP, #rtmp_message{stream_id = StreamId, type = invoke, body = AMF}).
  
init([Consumer]) ->
  link(Consumer),
  {ok, wait_for_socket, #rtmp_socket{consumer = Consumer, channels = array:new()}, ?RTMP_TIMEOUT}.

wait_for_socket({socket, Socket}, #rtmp_socket{} = State) ->
  inet:setopts(Socket, [{active, once}, {packet, raw}, binary]),
  {ok, {IP, Port}} = inet:peername(Socket),
  {next_state, handshake_c1, State#rtmp_socket{socket = Socket, address = IP, port = Port}, ?RTMP_TIMEOUT}.
  
loop(timeout, #rtmp_socket{pinged = false} = State) ->
  send_data(State, #rtmp_message{type = ping}),
  {next_state, loop, State#rtmp_socket{pinged = true}, ?RTMP_TIMEOUT};
  
loop(timeout, State) ->
  {stop, timeout, State};

loop({setopts, Options}, State) ->
  ?D({"Setopts", Options}),
  NewState = set_options(State, Options),
  {next_state, loop, NewState, ?RTMP_TIMEOUT}.
% , previous_ack = erlang:now()


set_options(State, [{amf_version, Version} | Options]) ->
  set_options(State#rtmp_socket{amf_version = Version}, Options);

set_options(State, [{chunk_size, ChunkSize} | Options]) ->
  send_data(State, #rtmp_message{type = chunk_size, body = ChunkSize}),
  set_options(State#rtmp_socket{server_chunk_size = ChunkSize}, Options);

set_options(State, []) -> State.
  
%%-------------------------------------------------------------------------
%% Func: handle_event/3
%% Returns: {next_state, NextStateName, NextStateData}          |
%%          {next_state, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}
%% @private
%%-------------------------------------------------------------------------
handle_event(Event, StateName, StateData) ->
  {stop, {StateName, undefined_event, Event}, StateData}.


%%-------------------------------------------------------------------------
%% Func: handle_sync_event/4
%% Returns: {next_state, NextStateName, NextStateData}            |
%%          {next_state, NextStateName, NextStateData, Timeout}   |
%%          {reply, Reply, NextStateName, NextStateData}          |
%%          {reply, Reply, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}                          |
%%          {stop, Reason, Reply, NewStateData}
%% @private
%%-------------------------------------------------------------------------

handle_sync_event(client_buffer, _From, loop, #rtmp_socket{client_buffer = ClientBuffer} = State) ->
  {reply, ClientBuffer, loop, State};

handle_sync_event(window_size, _From, loop, #rtmp_socket{window_size = WindowAckSize} = State) ->
  {reply, WindowAckSize, loop, State};

handle_sync_event(Event, _From, StateName, StateData) ->
  io:format("TRACE ~p:~p ~p~n",[?MODULE, ?LINE, got_sync_request2]),
  {stop, {StateName, undefined_event, Event}, StateData}.

%%-------------------------------------------------------------------------
%% Func: handle_info/3
%% Returns: {next_state, NextStateName, NextStateData}          |
%%          {next_state, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}
%% @private
%%-------------------------------------------------------------------------
handle_info({tcp, Socket, Data}, handshake_c1, #rtmp_socket{socket=Socket, buffer = Buffer, bytes_read = BytesRead} = State) when size(Buffer) + size(Data) < ?HS_BODY_LEN + 1 ->
  inet:setopts(Socket, [{active, once}]),
  {next_state, handshake_c1, State#rtmp_socket{buffer = <<Buffer/binary, Data/binary>>, bytes_read = BytesRead + size(Data)}, ?RTMP_TIMEOUT};
  
handle_info({tcp, Socket, Data}, handshake_c1, #rtmp_socket{socket=Socket, buffer = Buffer, bytes_read = BytesRead} = State) ->
  inet:setopts(Socket, [{active, once}]),
  <<?HS_HEADER, HandShake:?HS_BODY_LEN/binary, Rest/binary>> = <<Buffer/binary, Data/binary>>,
	Reply = rtmp:handshake(HandShake),
	send_data(State, [?HS_HEADER, Reply]),
	{next_state, 'handshake_c3', State#rtmp_socket{buffer = Rest, bytes_read = BytesRead + size(Data)}, ?RTMP_TIMEOUT};


handle_info({tcp, Socket, Data}, handshake_c3, #rtmp_socket{socket=Socket, buffer = Buffer, bytes_read = BytesRead} = State) when size(Buffer) + size(Data) < ?HS_BODY_LEN ->
  inet:setopts(Socket, [{active, once}]),
  {next_state, handshake_c3, State#rtmp_socket{buffer = <<Buffer/binary, Data/binary>>, bytes_read = BytesRead + size(Data)}, ?RTMP_TIMEOUT};
  
handle_info({tcp, Socket, Data}, handshake_c3, #rtmp_socket{socket=Socket, consumer = Consumer, buffer = Buffer, bytes_read = BytesRead} = State) ->
  inet:setopts(Socket, [{active, once}]),
  <<_HandShakeC3:?HS_BODY_LEN/binary, Rest/binary>> = <<Buffer/binary, Data/binary>>,
  Consumer ! {rtmp, self(), connected},
  {next_state, loop, handle_rtmp_data(State#rtmp_socket{bytes_read = BytesRead + size(Data)}, Rest), ?RTMP_TIMEOUT};

handle_info({tcp, Socket, Data}, loop, #rtmp_socket{socket=Socket, buffer = Buffer, bytes_read = BytesRead} = State) ->
  inet:setopts(Socket, [{active, once}]),
  {next_state, loop, handle_rtmp_data(State#rtmp_socket{bytes_read = BytesRead + size(Data)}, <<Buffer/binary, Data/binary>>), ?RTMP_TIMEOUT};

handle_info({tcp_closed, Socket}, _StateName, #rtmp_socket{socket = Socket, consumer = Consumer} = StateData) ->
  Consumer ! {rtmp, self(), disconnect},
  {stop, normal, StateData};

handle_info(#rtmp_message{} = Message, loop, State) ->
  {next_state, loop, send_data(State, Message), ?RTMP_TIMEOUT};



handle_info(_Info, StateName, StateData) ->
  ?D({"Some info handled", _Info, StateName, StateData}),
  {next_state, StateName, StateData, ?RTMP_TIMEOUT}.


send_data(State, #rtmp_message{} = Message) ->
  {NewState, Data} = rtmp:encode(State, Message),
  send_data(NewState, Data);
  
send_data(#rtmp_socket{socket = Socket} = State, Data) when is_port(Socket) ->
  gen_tcp:send(Socket, Data),
  State;

send_data(#rtmp_socket{socket = Socket} = State, Data) when is_pid(Socket) ->
  gen_fsm:send_event(Socket, {server_data, Data}),
  State.


handle_rtmp_data(State, Data) ->
  handle_rtmp_message(rtmp:decode(Data, State)).

handle_rtmp_message({#rtmp_socket{consumer = Consumer} = State, Message, Rest}) ->
  Consumer ! Message,
  handle_rtmp_message(rtmp:decode(Rest, State));

handle_rtmp_message({State, Rest}) -> State#rtmp_socket{buffer = Rest}.

%%-------------------------------------------------------------------------
%% Func: terminate/3
%% Purpose: Shutdown the fsm
%% Returns: any
%% @private
%%-------------------------------------------------------------------------
terminate(_Reason, _StateName, #rtmp_socket{socket=Socket}) ->
  (catch gen_tcp:close(Socket)),
  ok.


%%-------------------------------------------------------------------------
%% Func: code_change/4
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState, NewStateData}
%% @private
%%-------------------------------------------------------------------------
code_change(_OldVersion, _StateName, _State, _Extra) ->
  ok.

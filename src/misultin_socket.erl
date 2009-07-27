% ==========================================================================================================
% MISULTIN	- Socket
%
% >-|-|-<°>
% 
% Copyright (C) 2009, Roberto Ostinelli <roberto@ostinelli.net>, Sean Hinde.
% All rights reserved.
%
% Code portions from Sean Hinde have been originally taken under BSD license from Trapexit at the address:
% <http://www.trapexit.org/A_fast_web_server_demonstrating_some_undocumented_Erlang_features>
%
% BSD License
% 
% Redistribution and use in source and binary forms, with or without modification, are permitted provided
% that the following conditions are met:
%
%  * Redistributions of source code must retain the above copyright notice, this list of conditions and the
%	 following disclaimer.
%  * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
%	 the following disclaimer in the documentation and/or other materials provided with the distribution.
%  * Neither the name of the authors nor the names of its contributors may be used to endorse or promote
%	 products derived from this software without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
% WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
% PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
% ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
% TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
% ==========================================================================================================
-module(misultin_socket).
-vsn('0.1').

% API
-export([start_link/3]).

% callbacks
-export([init/3]).

% internale
-export([socket_loop/1]).

% records
-record(c, {
	sock,
	port,
	loop
}).

% includes
-include("../include/misultin.hrl").


% ============================ \/ API ======================================================================

% Function: {ok,Pid} | ignore | {error, Error}
% Description: Starts the socket.
start_link(ListenSocket, ListenPort, Loop) ->
	proc_lib:spawn_link(?MODULE, init, [ListenSocket, ListenPort, Loop]).

% Description: Initiates the socket.
init(ListenSocket, ListenPort, Loop) ->
	case catch gen_tcp:accept(ListenSocket) of
	{ok, Socket} ->
		?DEBUG(debug, "accepted an incoming TCP connection", []),
		% Send the cast message to the listener process to create a new acceptor
		misultin:create_acceptor(),
		{ok, {Addr, Port}} = inet:peername(Socket),
		C = #c{sock = Socket, port = ListenPort, loop = Loop},
		% jump to state 'request'
		?DEBUG(debug, "jump to state request", []),
		request(C, #req{peer_addr = Addr, peer_port = Port});
	_Else ->
		?DEBUG(error, "accept failed error: ~p", [_Else]),
		exit({error, accept_failed})
	end.

% ============================ /\ API ======================================================================


% ============================ \/ INTERNAL FUNCTIONS =======================================================

% REQUEST: wait for a HTTP Request line. Transition to state headers if one is received. 
request(C, Req) ->
	case gen_tcp:recv(C#c.sock, 0, 30000) of
		{ok, {http_request, Method, Path, Version}} ->
			headers(C, Req#req{vsn = Version, method = Method, uri = Path}, []);
		{error, {http_error, "\r\n"}} ->
			request(C, Req);
		{error, {http_error, "\n"}} ->
			request(C, Req);
		_Other ->
			exit(normal)
	end.

% HEADERS: collect HTTP headers. After the end of header marker transition to body state.
headers(C, Req, H) ->
	case gen_tcp:recv(C#c.sock, 0, ?server_idle_timeout) of
		{ok, {http_header, _, 'Content-Length', _, Val}} ->
			Len = list_to_integer(Val),
			headers(C, Req#req{content_length = Len}, [{'Content-Length', Len}|H]);
		{ok, {http_header, _, 'Connection', _, Val}} ->
			KeepAlive = keep_alive(Req#req.vsn, Val),
			headers(C, Req#req{connection = KeepAlive}, [{'Connection', Val}|H]);
		{ok, {http_header, _, Header, _, Val}} ->
			headers(C, Req, [{Header, Val}|H]);
		{error, {http_error, "\r\n"}} ->
			headers(C, Req, H);
		{error, {http_error, "\n"}} ->
			headers(C, Req, H);
		{ok, http_eoh} ->
			body(C, Req#req{headers = lists:reverse(H)});
		_Other ->
			exit(normal)
	end.

% Shall we keep the connection alive? Default case for HTTP/1.1 is yes, default for HTTP/1.0 is no.
% string:to_upper is used only as last resort.
keep_alive({1,1}, "close")		-> close;
keep_alive({1,1}, "Close")		-> close;
keep_alive({1,1}, Head) ->
	case string:to_upper(Head) of
		"CLOSE" -> close;
		_		-> keep_alive
	end;
keep_alive({1,0}, "Keep-Alive") -> keep_alive;
keep_alive({1,0}, Head) ->
	case string:to_upper(Head) of
		"KEEP-ALIVE"	-> keep_alive;
		_				-> close
	end;
keep_alive({0,9}, _)			-> close;
keep_alive(_Vsn, _KA)			-> close.

% BODY: collect the body of the HTTP request if there is one, and lookup and call the implementation callback.
% Depending on whether the request is persistent transition back to state request to await the next request or exit.
body(#c{sock = Sock} = C, Req) ->
	case Req#req.method of
		'GET' ->
			Close = handle_get(C, Req),
			case Close of
				close ->
					gen_tcp:close(Sock);
				keep_alive ->
					inet:setopts(Sock, [{packet, http}]),
					request(C, #req{})
			end;
		'POST' when is_integer(Req#req.content_length) ->
			inet:setopts(Sock, [{packet, raw}]),
			case gen_tcp:recv(Sock, Req#req.content_length, 60000) of
				{ok, Bin} ->
					Close = handle_post(C, Req#req{body = Bin}),
					case Close of
						close ->
							gen_tcp:close(Sock);
						keep_alive ->
							inet:setopts(Sock, [{packet, http}]),
							request(C, #req{})
					end;
				_Other ->
					exit(normal)
			end;
		_Other ->
			send(C#c.sock, ?not_implemented_501),
			exit(normal)
	end.

% handle a get request
handle_get(C, #req{connection = Conn} = Req) ->
	case Req#req.uri of
		{abs_path, Path} ->
			{F, Args} = split_at_q_mark(Path, []),
			call_mfa(C, Req#req{args = Args, uri = {abs_path, F}}),
			Conn;
		{absoluteURI, http, _Host, _, Path} ->
			{F, Args} = split_at_q_mark(Path, []),
			call_mfa(C, Req#req{args = Args, uri = {absoluteURI, F}}),
			Conn;
		{absoluteURI, _Other_method, _Host, _, _Path} ->
			send(C#c.sock, ?not_implemented_501),
			close;
		{scheme, _Scheme, _RequestString} ->
			send(C#c.sock, ?not_implemented_501),
			close;
		_  ->
			send(C#c.sock, ?forbidden_403),
			close
	end.

% handle a post request
handle_post(C, #req{connection = Conn} = Req) ->
	case Req#req.uri of
		{abs_path, _Path} ->
			call_mfa(C, Req),
			Conn;
		{absoluteURI, http, _Host, _, _Path} ->
			call_mfa(C, Req),
			Conn;
		{absoluteURI, _Other_method, _Host, _, _Path} ->
			send(C#c.sock, ?not_implemented_501),
			close;
		{scheme, _Scheme, _RequestString} ->
			send(C#c.sock, ?not_implemented_501),
			close;
		_  ->
			send(C#c.sock, ?forbidden_403),
			close
	end.

% Description: Main dispatcher
call_mfa(#c{sock = Sock, loop = Loop} = C, Request) ->
	% spawn listening process for Request messages
	SocketPid = spawn(?MODULE, socket_loop, [C]),
	% create request
	Req = misultin_req:new(Request, SocketPid),
	% call loop
	case catch Loop(Req) of
		{'EXIT', _Reason} ->
			?DEBUG(error, "worker crash: ~p", [_Reason]),
			send(Sock, ?internal_server_error_500),
			% kill listening socket
			SocketPid ! shutdown,
			exit(normal);
		_ ->
			% loop exited normally, kill listening socket
			SocketPid ! shutdown
	end.
	
% Description: Socket	TODO: HANDLE LOOP CRASH
socket_loop(#c{sock = Sock} = C) ->
	receive
		{stream_open, HttpCode, Headers} ->
			?DEBUG(debug, "sending stream opening", []),
			Enc_headers = enc_headers(Headers),
			Resp = [list_to_binary(lists:flatten(io_lib:format("HTTP/1.1 ~p OK\r\n", [HttpCode]))), Enc_headers, <<"\r\n">>],
			send(Sock, Resp),
			socket_loop(C);
		{stream_data, Body} ->
			send(Sock, Body),
			socket_loop(C);
		stream_close ->
			?DEBUG(debug, "closing stream", []),
			close(Sock);
		{HttpCode, Headers0, Body} ->
			?DEBUG(debug, "sending response", []),
			Headers = add_content_length(Headers0, Body),
			Enc_headers = enc_headers(Headers),
			Resp = [list_to_binary(lists:flatten(io_lib:format("HTTP/1.1 ~p OK\r\n", [HttpCode]))), Enc_headers, <<"\r\n">>, Body],
			send(Sock, Resp);
		shutdown ->
			shutdown
	end.

% Description: Add content length
add_content_length(Headers, Body) ->
	case lists:keysearch('Content-Length', 1, Headers) of
		{value, _} ->
			Headers;
		false ->
			[{'Content-Length', size(Body)}|Headers]
	end.

% Description: Encode headers
enc_headers([{Tag, Val}|T]) when is_atom(Tag) ->
	[atom_to_list(Tag), ": ", enc_header_val(Val), "\r\n"|enc_headers(T)];
enc_headers([{Tag, Val}|T]) when is_list(Tag) ->
	[Tag, ": ", enc_header_val(Val), "\r\n"|enc_headers(T)];
enc_headers([]) ->
	[].
enc_header_val(Val) when is_atom(Val) ->
	atom_to_list(Val);
enc_header_val(Val) when is_integer(Val) ->
	integer_to_list(Val);
enc_header_val(Val) ->
	Val.

% Split the path at the ?
split_at_q_mark([$?|T], Acc) ->
	{lists:reverse(Acc), T};
split_at_q_mark([H|T], Acc) ->
	split_at_q_mark(T, [H|Acc]);
split_at_q_mark([], Acc) ->
	{lists:reverse(Acc), []}.

% TCP send
send(Sock, Data) ->
	case gen_tcp:send(Sock, Data) of
		ok ->
			ok;
		{error, _Reason} ->
			?DEBUG(debug, "worker crash: ~p", [_Reason]),
			exit(normal)
	end.

% TCP close
close(Sock) ->
	case gen_tcp:close(Sock) of
		ok ->
			ok;
		{error, _Reason} ->
			?DEBUG(debug, "could not close socket: ~p", [_Reason]),
			exit(normal)
	end.
	
% ============================ /\ INTERNAL FUNCTIONS =======================================================

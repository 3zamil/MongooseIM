%%%----------------------------------------------------------------------
%%% File    : ejabberd_odbc_sup.erl
%%% Author  : Alexey Shchepin <alexey@process-one.net>
%%% Purpose : ODBC connections supervisor
%%% Created : 22 Dec 2004 by Alexey Shchepin <alexey@process-one.net>
%%%
%%%
%%% ejabberd, Copyright (C) 2002-2011   ProcessOne
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%----------------------------------------------------------------------

-module(ejabberd_odbc_sup).
-author('alexey@process-one.net').

%% API
-export([start_link/1,
         init/1,
         get_pids/1,
         default_pool/1,
         add_pool/4,
         remove_pool/2
        ]).

-include("ejabberd.hrl").

-define(POOL_NAME, odbc_pool).
-define(DEFAULT_POOL_SIZE, 10).
-define(DEFAULT_ODBC_START_INTERVAL, 30). % 30 seconds

% time to wait for the supervisor to start its child before returning
% a timeout error to the request
-define(CONNECT_TIMEOUT, 500). % milliseconds

-spec start_link(binary() | string()) -> 'ignore' | {'error',_} | {'ok',pid()}.
start_link(Host) ->
    supervisor:start_link({local, gen_mod:get_module_proc(Host, ?MODULE)},
                          ?MODULE, [Host]).

-spec init([ejabberd:server(),...]) -> {'ok',{{_,_,_},[any()]}}.
init([Host]) ->
    PoolSize = pool_size(Host),
    PoolName = gen_mod:get_module_proc(Host, ?POOL_NAME),
    ChildrenSpec = [pool_spec(Host, default_pool, {local, PoolName}, PoolSize)],
    {ok, {{one_for_one, PoolSize * 10, 1}, ChildrenSpec}}.


add_pool(Host, Id, Name, Size) ->
    Sup = gen_mod:get_module_proc(Host, ?MODULE),
    ChildSpec = pool_spec(Host, Id, Name, Size),
    supervisor:start_child(Sup, ChildSpec).


remove_pool(Host, Id) ->
    Sup = gen_mod:get_module_proc(Host, ?MODULE),
    ok = supervisor:terminate_child(Sup, Id),
    ok = supervisor:delete_child(Sup, Id).


pool_spec(Host, Id, Name, Size) ->
    PoolboyArgs = [{name, Name}, {worker_module, ejabberd_odbc}, {size, Size}],
    poolboy:child_spec(Id, PoolboyArgs, Host).


-spec get_pids(ejabberd:server()) -> [pid()].
get_pids(Host) ->
    pg2:get_members({Host, ejabberd_odbc}).


default_pool(Host) ->
    gen_mod:get_module_proc(Host, ?POOL_NAME).


-spec pool_size(ejabberd:server()) -> integer().
pool_size(Host) ->
    case ejabberd_config:get_local_option({odbc_pool_size, Host}) of
        undefined ->
            ?DEFAULT_POOL_SIZE;
        Size when is_integer(Size) ->
            Size;
        InvalidSize ->
            Size = ?DEFAULT_POOL_SIZE,
            ?ERROR_MSG("Wrong odbc_pool_size definition '~p' "
                       "for host ~p, default to ~p~n",
                       [InvalidSize, Host, Size]),
            Size
    end.

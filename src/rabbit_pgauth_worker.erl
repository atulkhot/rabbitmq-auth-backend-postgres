%% Copyright (c) 2007-2016 Pivotal Software, Inc.
%% You may use this code for any purpose.

-module(rabbit_pgauth_worker).

-include_lib("epgsql/include/epgsql.hrl").

-behaviour(gen_server).
-behaviour(rabbit_authn_backend).
-behaviour(rabbit_authz_backend).

-export([start_link/0]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
  terminate/2, code_change/3,
  user_login_authentication/2, user_login_authorization/1,
  check_vhost_access/3, check_resource_access/3, check_topic_access/4]).

-include_lib("amqp_client/include/amqp_client.hrl").

-define(SERVER, ?MODULE).

-define(CHECK_RESOURCE_ACCESS_HEADERS, [username, vhost, resource, name, permission]).

-record(state, {}).

-define(RKFormat,
  "~4.10.0B.~2.10.0B.~2.10.0B.~1.10.0B.~2.10.0B.~2.10.0B.~2.10.0B").

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%---------------------------
% Gen Server Implementation
% --------------------------

init([]) ->
  {ok, #state{}}.

check_resource_access(#auth_user{username = Username},
    #resource{virtual_host = VHost, kind = Type, name = Name},
    Permission) ->
  gen_server:call(?SERVER, {check_resource, [{username, Username},
    {vhost, VHost},
    {resource, Type},
    {name, Name},
    {permission, Permission}]},
    infinity).

check_vhost_access(#auth_user{username = Username}, VHost, _Sock) ->
  gen_server:call(?SERVER, {check_vhost, [{username, Username},
    {vhost, VHost}]},
    infinity).

check_topic_access(#auth_user{username = Username},
    #resource{virtual_host = VHost, kind = topic = Type, name = Name},
    Permission,
    Context) ->
  OptionsHeaders = context_as_headers(Context),
  gen_server:call(?SERVER, {check_topic, [{username,   Username},
    {vhost,      VHost},
    {resource,   Type},
    {name,       Name},
    {permission, Permission}] ++ OptionsHeaders},
    infinity).

context_as_headers(Options) when is_map(Options) ->
  % filter options that would erase fixed parameters
  [{rabbit_data_coercion:to_atom(Key), maps:get(Key, Options)}
    || Key <- maps:keys(Options),
    lists:member(
      rabbit_data_coercion:to_atom(Key),
      ?CHECK_RESOURCE_ACCESS_HEADERS) =:= false];
context_as_headers(_) ->
  [].

user_login_authentication(Username, AuthProps) ->
  gen_server:call(?SERVER, {login, Username, AuthProps}, infinity).

user_login_authorization(Username) ->
  gen_server:call(?SERVER, {authorization, Username}, infinity).

extract_pwd_as_str(AuthProps) ->
  Tup_password = lists:keyfind(password, 1, AuthProps),
  Password = element(2, Tup_password),
  binary:bin_to_list(Password).

predef_user_name() ->
  {ok, Predef_user_name} = application:get_env(predef_user_name),
  Predef_user_name.

guess_auth_type(Idstr) -> case re:run(Idstr, "^" ++ predef_user_name() ++ "$", [{capture, all_but_first, list}]) of
                              {match, _} -> {maybe_predef, Idstr};
                              _ -> {checkindb, Idstr}
                     end.

check_login({checkindb, SerialNumStr, Password, CONN}) ->
  epgsql:equery(CONN, "select count(*) from authentication where name = $1 and password = $2", [SerialNumStr, Password]);

check_login({maybe_predef, DroneIdStr, Password, _CONN}) ->
  {ok, Predef_user_name} = application:get_env(predef_user_name),
  {ok, Predef_passwd} = application:get_env(predef_user_password),
  io:format("In predef - Predef_User = ~p, Predef_Password = ~p~n", [Predef_user_name, Predef_passwd]),

  case {string:equal(DroneIdStr, Predef_user_name), string:equal(Password, Predef_passwd)} of
    {true, true} -> {ok, "OK", [{1}]};
    _ -> {nomatch, "No", [{0}]}
  end.

get_db_conn() ->
  {ok, PG_Host} = application:get_env(postgres_host),
  {ok, PG_Username} = application:get_env(postgres_user),
  {ok, PG_Password} = application:get_env(postgres_passwd),
  {ok, PG_Database} = application:get_env(postgres_db),
  {ok, PG_Query_Timeout} = application:get_env(postgres_query_timeout),
  epgsql:connect(PG_Host, PG_Username, PG_Password, [
    {database, PG_Database},
    {timeout, PG_Query_Timeout}
  ]).

handle_call({login, Username, AuthProps}, _From, State) ->
  {ok, CONN} = get_db_conn(),
  U = binary:bin_to_list(Username),
  P = extract_pwd_as_str(AuthProps),
  {ItsType, DroneIdStr} = guess_auth_type(U),
  SelectRes = check_login({ItsType, DroneIdStr, P, CONN}),
%%  io:format("~p~n", [SelectRes]),
  Res = case SelectRes of
          {ok, _, [{K}]} when K > 0 -> {ok, #auth_user{username = Username,
            tags = [administrator],
            impl = none}};
          _ -> {refused, "Denied by Metronome plugin", []}
        end,
  ok = epgsql:close(CONN),
  {reply, Res, State};

handle_call({check_vhost, _Args}, _From, State) ->
  {reply, true, State};

handle_call({check_resource, _Args}, _From, State) ->
  {reply, true, State};

handle_call({check_topic, _Args}, _From, State) ->
  {reply, true, State}.

handle_cast(_, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_, #state{}) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

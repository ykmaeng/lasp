%% -------------------------------------------------------------------
%%
%% Copyright (c) 2016 Christopher Meiklejohn.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(lasp_simulate_resource).
-author("Christopher Meiklejohn <christopher.meiklejohn@gmail.com>").

-export([init/1,
         content_types_provided/2,
         to_json/2]).

-include("lasp.hrl").
-include_lib("webmachine/include/webmachine.hrl").

-define(NUM_EVENTS, 100).
-define(NUM_CLIENTS, 100).
-define(SYNC_INTERVAL, 10).

-define(ORSET, lasp_orset).
-define(COUNTER, lasp_gcounter).

-spec init(list()) -> {ok, term()}.
init(_) ->
    {ok, undefined}.

%% return the list of available content types for webmachine
content_types_provided(Req, Ctx) ->
    {[{"application/json", to_json}], Req, Ctx}.

to_json(ReqData, State) ->
    {ok, Nodes} = lasp_peer_service:members(),
    {ok, _} = lasp_simulation:run(lasp_advertisement_counter,
                                  [Nodes,
                                   ?ORSET,
                                   ?COUNTER,
                                   ?NUM_EVENTS,
                                   ?NUM_CLIENTS,
                                   ?SYNC_INTERVAL]),
    PrivDir = code:priv_dir(?APP),
    LogDir = PrivDir ++ "/logs",
    PlotDir = PrivDir ++ "/plots",
    InputFile1 = LogDir ++ input_file(client),
    InputFile2 = LogDir ++ input_file(server),
    GnuPlot = PlotDir ++ "/advertisement_counter-transmission.gnuplot",
    OutputFile = PlotDir ++ output_file(),
    plot(InputFile1, InputFile2, OutputFile, GnuPlot),
    Encoded = jsx:encode(#{status => ok,
                           nodes => Nodes,
                           files => [InputFile1, InputFile2, OutputFile, GnuPlot]}),
    {Encoded, ReqData, State}.

%% @private
input_file(Type) ->
    "/lasp_transmission_instrumentation-" ++ atom_to_list(Type) ++ "-" ++
    atom_to_list(?ORSET) ++ "-" ++ atom_to_list(?COUNTER) ++ "-" ++
    integer_to_list(?NUM_EVENTS) ++ "-" ++ integer_to_list(?NUM_CLIENTS)
    ++ "-" ++ integer_to_list(?SYNC_INTERVAL) ++ ".csv".

%% @private
output_file() ->
    "/lasp_transmission_instrumentation-" ++
    atom_to_list(?ORSET) ++ "-" ++ atom_to_list(?COUNTER) ++ "-" ++
    integer_to_list(?NUM_EVENTS) ++ "-" ++ integer_to_list(?NUM_CLIENTS)
    ++ "-" ++ integer_to_list(?SYNC_INTERVAL) ++ ".pdf".

%% @private
plot(InputFile1, InputFile2, OutputFile, GnuPlot) ->
    Command = "gnuplot -e \"inputfile1='" ++ InputFile1 ++ "'; inputfile2='" ++ InputFile2 ++ "'; outputname='" ++ OutputFile ++ "'\" " ++ GnuPlot,
    Result = os:cmd(Command),
    lager:info("Generating PNG plot: ~p; output: ~p", [Command, Result]).

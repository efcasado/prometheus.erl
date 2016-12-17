%%%========================================================================
%%% File: prometheus_vm_process_info_collector.erl
%%%
%%%
%%% Author(s):
%%%   - Enrique Fernandez <efcasado@gmail.com>
%%%
%%% The MIT License (MIT)
%%%
%%% Copyright (c) 2016, Enrique Fernandez
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%%========================================================================

%% @doc
%% Collects Erlang VM metrics using
%% <a href="http://erlang.org/doc/man/erlang.html#process_info-2">
%%   erlang:process_info/2
%% </a>.
%%
%% ==Exported metrics==
%% <ul>
%%   <li>
%%     `erlang_vm_ets_limit'<br/>
%%     Type: gauge.<br/>
%%     The maximum number of ETS tables allowed.
%%   </li>
%%   <li>
%%     `erlang_vm_time_correction'<br/>
%%     Type: boolean.<br/>
%%     1 if time correction is enabled, otherwise 0.
%%   </li>
%% </ul>
%%
%% ==Configuration==
%%
%% Metrics exported by this collector can be configured via
%% `vm_process_info_collector_metrics' key of `prometheus' app environment.
%%
%% Options are the same as Item parameter values for
%% <a href="http://erlang.org/doc/man/erlang.html#process_info-2">
%%   erlang:process_info/2
%% </a>:
%% <ul>
%%   <li>
%%     `message_queue_len' for `erlang_vm_process_msg_queue_length'.
%%   </li>
%%   <li>
%%     `reductions' for `erlang_vm_process_reductions'.
%%   </li>
%% </ul>
%%
%% By default all metrics are enabled.
%% @end
-module(prometheus_vm_process_info_collector).

-export([deregister_cleanup/1,
         collect_mf/2,
         collect_metrics/2]).

-import(prometheus_model_helpers, [create_mf/5,
                                   untyped_metric/1,
                                   gauge_metric/1,
                                   gauge_metric/2,
                                   counter_metric/1,
                                   counter_metric/2]).

-include("prometheus.hrl").

-behaviour(prometheus_collector).

%%====================================================================
%% Macros
%%====================================================================

-define(MSG_QUEUE_LENGTH, erlang_vm_process_message_queue_length).
-define(HEAP_SIZE, erlang_vm_process_heap_size).
-define(STACK_SIZE, erlang_vm_process_stack_size).
-define(REDUCTIONS, erlang_vm_process_reductions).

-define(PROMETHEUS_VM_PROCESS_INFO, [
                                     message_queue_len,
                                     heap_size,
                                     stack_size,
                                     reductions
                                    ]).

%%====================================================================
%% Collector API
%%====================================================================

%% @private
deregister_cleanup(_) -> ok.

-spec collect_mf(_Registry, Callback) -> ok when
    _Registry :: prometheus_registry:registry(),
    Callback :: prometheus_collector:callback().
%% @private
collect_mf(_Registry, Callback) ->
  [call_if_process_info_exists(MFName,
                              fun(Value) ->
                                  add_metric_family(MFName, Value, Callback)
                              end)
   || MFName <- enabled_process_info_metrics()],
  ok.

add_metric_family(message_queue_len, Value, Callback) ->
  Callback(create_gauge(?MSG_QUEUE_LENGTH,
                        "The number of messages currently in the "
                        "message queue of the process.",
                        Value));
add_metric_family(heap_size, Value, Callback) ->
  Callback(create_gauge(?HEAP_SIZE,
                        "The size in words of the youngest "
                        "heap generation of the process. This "
                        "generation includes the process stack.",
                        Value));
add_metric_family(stack_size, Value, Callback) ->
  Callback(create_gauge(?STACK_SIZE,
                        "The stack size, in words, of the process.",
                        Value));
add_metric_family(reductions, Value, Callback) ->
  Callback(create_gauge(?REDUCTIONS,
                        "The number of reductions executed by "
                        "the process.",
                        Value)).

%% @private
collect_metrics(_, {PID, Value}) ->
  gauge_metric([PID], Value).

%%====================================================================
%% Private Parts
%%====================================================================

call_if_process_info_exists(ProcInfoItem, Fun) ->
    [case erlang:process_info(P, ProcInfoItem) of
         {ProcInfoItem, V} -> Fun({{pid, P}, V});
         undefined -> Fun({{pid, P}, undefined})
     end
     || P <- erlang:processes()].

enabled_process_info_metrics() ->
  application:get_env(prometheus, vm_process_info_collector_metrics,
                      ?PROMETHEUS_VM_PROCESS_INFO).

create_gauge(Name, Help, Data) ->
  create_mf(Name, Help, gauge, ?MODULE, Data).

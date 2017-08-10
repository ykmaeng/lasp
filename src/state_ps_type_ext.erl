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

-module(state_ps_type_ext).

-author("Junghun Yoo <junghun.yoo@cs.ox.ac.uk>").

-export([
    map/2,
    filter/2,
    union/2,
    product/2]).

map(Function, {state_ps_aworset_naive, Payload}) ->
    NewPayload = map_internal(Function, Payload),
    {state_ps_aworset_naive, NewPayload}.

filter(Function, {state_ps_aworset_naive, Payload}) ->
    NewPayload = filter_internal(Function, Payload),
    {state_ps_aworset_naive, NewPayload}.

union(
    {state_ps_aworset_naive, PayloadL}, {state_ps_aworset_naive, PayloadR}) ->
    NewPayload = union_internal(PayloadL, PayloadR),
    {state_ps_aworset_naive, NewPayload}.

product(
    {state_ps_aworset_naive, PayloadL}, {state_ps_aworset_naive, PayloadR}) ->
    NewPayload = product_internal(PayloadL, PayloadR),
    {state_ps_aworset_naive, NewPayload}.

%% @private
map_internal(Function, {ProvenanceStore, SubsetEvents, AllEvents}=_POEORSet) ->
    MapProvenanceStore =
        orddict:fold(
            fun(Elem, Provenance, AccInMapProvenanceStore) ->
                orddict:update(
                    Function(Elem),
                    fun(OldProvenance) ->
                        state_ps_type:plus_provenance(OldProvenance, Provenance)
                    end,
                    Provenance,
                    AccInMapProvenanceStore)
            end, orddict:new(), ProvenanceStore),
    {MapProvenanceStore, SubsetEvents, AllEvents}.

%% @private
filter_internal(Function, {ProvenanceStore, SubsetEvents, AllEvents}=_POEORSet) ->
    FilterProvenanceStore =
        orddict:fold(
            fun(Elem, Provenance, AccInFilterProvenanceStore) ->
                case Function(Elem) of
                    true ->
                        orddict:store(
                            Elem, Provenance, AccInFilterProvenanceStore);
                    false ->
                        AccInFilterProvenanceStore
                end
            end, orddict:new(), ProvenanceStore),
    {FilterProvenanceStore, SubsetEvents, AllEvents}.

%% @private
union_internal(POEORSetL, POEORSetR) ->
    state_ps_poe_orset:join(POEORSetL, POEORSetR).

%% @private
product_internal(
    {ProvenanceStoreL, SubsetEventsL, AllEventsL}=_POEORSetL,
    {ProvenanceStoreR, SubsetEventsR, AllEventsR}=_POEORSetR) ->
    ProductAllEvents = state_ps_type:join_all_events(AllEventsL, AllEventsR),
    ProductSubsetEvents =
        state_ps_type:join_subset_events(
            SubsetEventsL, AllEventsL, SubsetEventsR, AllEventsR),
    {CrossedProvenanceStore, NewEvents} =
        orddict:fold(
            fun(ElemL,
                ProvenanceL,
                {AccProductProvenanceStoreL, AccNewEventsL}) ->
                orddict:fold(
                    fun(ElemR,
                        ProvenanceR,
                        {AccProductProvenanceStoreLR, AccNewEventsLR}) ->
                        ProductElem = {ElemL, ElemR},
                        {ProductProvenance, ProductNewEvents} =
                            state_ps_type:cross_provenance(
                                ProvenanceL, ProvenanceR),
                        NewProductProvenanceStore =
                            orddict:store(
                                ProductElem,
                                ProductProvenance,
                                AccProductProvenanceStoreLR),
                        {NewProductProvenanceStore,
                            ordsets:union(AccNewEventsLR, ProductNewEvents)}
                    end,
                    {AccProductProvenanceStoreL, AccNewEventsL},
                    ProvenanceStoreR)
            end,
            {orddict:new(), ordsets:new()},
            ProvenanceStoreL),
    NewProductAllEvents =
        state_ps_type:event_set_max(
            state_ps_type:event_set_union(ProductAllEvents, NewEvents)),
    NewProductSubsetEvents =
        state_ps_type:event_set_max(
            state_ps_type:event_set_union(ProductSubsetEvents, NewEvents)),
    ProductProvenanceStore =
        prune_provenance_store(CrossedProvenanceStore, NewProductSubsetEvents),
    {ProductProvenanceStore, NewProductSubsetEvents, NewProductAllEvents}.

%% @private
prune_provenance_store(ProvenanceStore, Events) ->
    orddict:fold(
        fun(Elem, Provenance, AccPrunedProvenanceStore) ->
            NewProvenance =
                ordsets:fold(
                    fun(Dot, AccNewProvenance) ->
                        case ordsets:is_subset(Dot, Events) of
                            true ->
                                ordsets:add_element(Dot, AccNewProvenance);
                            false ->
                                AccNewProvenance
                        end
                    end,
                    ordsets:new(),
                    Provenance),
            case NewProvenance of
                [] ->
                    AccPrunedProvenanceStore;
                _ ->
                    orddict:store(Elem, NewProvenance, AccPrunedProvenanceStore)
            end
        end,
        orddict:new(),
        ProvenanceStore).

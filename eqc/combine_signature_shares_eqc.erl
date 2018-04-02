-module(combine_signature_shares_eqc).

-include_lib("eqc/include/eqc.hrl").

-export([prop_combine_signature_shares/0]).

prop_combine_signature_shares() ->
    ?FORALL({Players, Threshold, Curve}, gen_players_threshold_curve(),
            begin
                dealer:start_link(Players, Threshold, Curve),
                {ok, K} = dealer:adversaries(),
                {ok, _Group} = dealer:group(),
                {ok, _G1, G2, PubKey, PrivateKeys} = dealer:deal(),
                MessageToSign = tpke_pubkey:hash_message(PubKey, crypto:hash(sha256, crypto:strong_rand_bytes(12))),
                Signatures = [ tpke_privkey:sign(PrivKey, MessageToSign) || PrivKey <- PrivateKeys],
                Sig = tpke_pubkey:combine_signature_shares(PubKey, dealer:random_n(K, Signatures)),
                ?WHENFAIL(begin
                              io:format("Signatures ~p~n", [[ erlang_pbc:element_to_string(S) || {_, S} <- Signatures]])
                          end,
                          conjunction([
                                       {verify_signature_share, eqc:equals(true, lists:all(fun(X) -> X end, [tpke_pubkey:verify_signature_share(PubKey, G2, Share, MessageToSign) || Share <- Signatures]))},
                                       {verify_combine_signature_shares, eqc:equals(true, tpke_pubkey:verify_signature(PubKey, G2, Sig, MessageToSign))}
                                      ]))
            end).

gen_players_threshold_curve() ->
    ?SUCHTHAT({Players, Threshold, Curve}, ?LET({X, Y, Z}, {int(), int(), 'SS512'}, {X, Y*3, Z}), Players > 3*Threshold+1).
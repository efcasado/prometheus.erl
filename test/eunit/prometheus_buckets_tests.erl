-module(prometheus_buckets_tests).

-include_lib("eunit/include/eunit.hrl").

linear_generator_errors_test() ->
  ?assertError({invalid_value, 0, "Buckets count should be positive"}, prometheus_buckets:generate_linear(-15, 5, 0)).

linear_generator_test() ->
  ?assertEqual([-15, -10, -5, 0, 5, 10], prometheus_buckets:generate_linear(-15, 5, 6)).

exponential_generator_errors_test() ->
  ?assertError({invalid_value, 0, "Buckets count should be positive"}, prometheus_buckets:generate_exponential(-15, 5, 0)),
  ?assertError({invalid_value, -15, "Buckets start should be positive"}, prometheus_buckets:generate_exponential(-15, 5, 2)),
  ?assertError({invalid_value, 0.5, "Buckets factor should be greater than 1"}, prometheus_buckets:generate_exponential(15, 0.5, 3)).

exponential_generator_test() ->
  ?assertEqual([100, 120, 144], prometheus_buckets:generate_exponential(100, 1.2, 3)).

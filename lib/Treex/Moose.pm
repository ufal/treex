package Treex::Moose;
use Treex::Core;
use Moose;
use Moose::Exporter;
use MooseX::SemiAffordanceAccessor::Role::Attribute;
use Treex::Core::Log;
#use List::MoreUtils qw(first_index);

Moose::Exporter->setup_import_methods(
    also            => 'Moose',
    class_metaroles => {attribute => ['MooseX::SemiAffordanceAccessor::Role::Attribute']},
    as_is => [
        \&Treex::Core::Log::log_fatal,
        \&Treex::Core::Log::log_warn,
        \&Treex::Core::Log::log_debug,
        \&Treex::Core::Log::log_memory,
        \&Treex::Core::Log::log_set_error_level,
        \&Treex::Core::Log::log_info,
        #\&List::MoreUtils::first_index,
    ] 
);

1;
# Write just
#   use Treex::Moose;
# Instead of
#   use Moose;
#   use MooseX::SemiAffordanceAccessor;

#TODO: add
#   use List::MoreUtils qw(first_index ...);

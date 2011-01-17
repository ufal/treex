package Treex::Moose;
use Moose;
use Moose::Exporter;
use MooseX::SemiAffordanceAccessor::Role::Attribute;
#use List::MoreUtils qw(first_index);

Moose::Exporter->setup_import_methods(
    also            => 'Moose',
    class_metaroles => {attribute => ['MooseX::SemiAffordanceAccessor::Role::Attribute']},
    #as_is => [ \&List::MoreUtils::first_index, ] 
);

1;
# Write just
#   use Treex::Moose;
# Instead of
#   use Moose;
#   use MooseX::SemiAffordanceAccessor;

#TODO: add
#   use List::MoreUtils qw(first_index ...);

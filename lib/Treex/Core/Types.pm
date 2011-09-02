package Treex::Core::Types;
use Moose::Util::TypeConstraints;

subtype 'Treex::Type::NonNegativeInt'
    => as 'Int'
    => where {$_ >= 0}
=> message {"$_ isn't non-negative"};


__END__

=encoding utf-8

=head1 NAME

Treex::Core::Types - types used in Treex framework

=head1 DESCRIPTION

=head1 TYPES

=over 4

=item NonNegativeInt



=back

TODO POD

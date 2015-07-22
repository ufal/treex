package Treex::Core::RememberArgs;
use Moose::Role;

has args => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_args',
    default => sub {return {};},
);

has args_str => (
    is => 'ro',
    isa => 'Str',
    writer => '_set_args_str',
    default => '',
);

# Empty BUILD is needed, so we can use "after BUILD".
# "after BUILD" is needed because we cannot (and don't want to)
# override the BUILD which may be present in the class which will consume this role.
# See http://rjbs.manxome.org/rubric/entry/1864
sub BUILD {}
after BUILD => sub {
    my ($self, $args) = @_;
    $self->_set_args($args);
    my $str = '';
    while (my ($key, $value) = each %{$args}){
        if ($value =~ /\s/){
            $value =~ s/'/\\'/g;
            $value = "'$value'";
        }
        $str .= "$key=$value ";
    }
    $str =~ s/ $//;
    $self->_set_args_str($str);
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::RememberArgs - role for remembering constructor's arguments

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    with 'Treex::Core::RememberArgs';
    has num => (is=>'rw');
    1;
    
    package Main;
    use MyClass;
    my $object = MyClass->({foo=>'bar baz', num=>42});
    say $object->args_str;
    # prints
    # foo='bar baz' num=42
    my $foo = $object->args->{foo};
   
    
=head1 DESCRIPTION

Moose role that saves all arguments that were passed to the constructor.
These arguments are then available either as a hashref in attribute C<args>
or as a string in form I<arg1=value1 arg2=val2 ...> in attribute C<args_str>.
Values containing spaces are enclosed in single quotes (and quotes inside the value escaped).

Unlike L<MooseX::SlurpyConstructor>, this role stores also the arguments
which are defined as attributes of the class (C<num> in the Synopsis).

Expected use cases:
Treex scenarios need to serialize all the parameters
and propagate them to nested scenarios.
See e.g. L<Treex::Scen::EN2CS>.

=head1 ATTRIBUTES

=head2 args

hash ref with the original arguments

=head2 args_str

stringified original arguments

=head1 SEE ALSO

L<MooseX::SlurpyConstructor>

L<MooseX::StrictConstructor>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

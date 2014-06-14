package Treex::Tool::Interset::Driver;
use utf8;
use Treex::Core::Log;
use Moose::Role;
use List::MoreUtils qw(uniq);
requires 'decoding_table';

has _subtags => (
    is => 'ro',
    lazy_build => 1,
);

sub _build__subtags {
    my ($self) = @_;
    return [sort {length $b <=> length $a} keys %{$self->decoding_table}];
}

sub driver_name {
    my ($self) = @_;
    my $class_name = ref $self;
    $class_name =~ s/^Treex::Tool::Interset:://;
    return $class_name;
}

sub BUILD {}
after BUILD => sub {
    my ($self) = @_;
    my $driver_name = $self->driver_name;
    my $decoding_table = $self->decoding_table;
    foreach my $tag ( keys %$decoding_table ) {
        $decoding_table->{$tag}{tagset} = $driver_name;
    }
    return;
};

# The default implementation of split_tag
# searches for substrings of $orig_tag that match left-hand side of rules in decoding_table.
# It starts with the strings to prevent clashes.
# Though this implementation may give reasonable results for many drivers,
# it is recommended to override it with driver-specific code for faster processing.
sub split_tag {
    my ($self, $orig_tag) = @_;
    my @found;
    foreach my $subtag (@{$self->_subtags}){
        if ($orig_tag =~ s/\Q$subtag\E//){
            push @found, $subtag;
        }
    }
    return @found;
}

sub decode {
    my ($self, $orig_tag) = @_;
    my @subtags = $self->split_tag($orig_tag);
    my $iset = {};
    foreach my $subtag (@subtags) {
        my $substructure = $self->decoding_table->{$subtag};
        if (!$substructure){
            log_warn "No Interset entry for '$subtag' (from '$orig_tag')";
            next;
        }
        while (my ($key, $value) = each %{$substructure}){
            next if $key eq 'tagset';
            my $old_value = $iset->{$key};
            if (!defined $old_value){
                $iset->{$key} = $value;
            } elsif ($old_value eq $value) {
                # Prevent creating [$value] if both $old_value and $value
                # are the same string (and therefor neither is an array ref).
            } else {
                my @old_values = ref $old_value eq 'ARRAY' ? @$old_value : ($old_value);
                my @new_values = ref $value eq 'ARRAY' ? @$value : ($value);
                $iset->{$key} = [uniq(@old_values, @new_values)];
            }
        }
    }
    return $iset;
}

sub encode { log_fatal "Method 'encode' not implemented"; }
sub list { log_fatal "Method 'list' not implemented"; }

1;

__END__

=head1 NAME

Treex::Tool::Interset::Driver

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

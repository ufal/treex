package Treex::Block::A2N::SimpleNER;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has model_name => (
    is => 'ro',
    isa => 'Str',
    default => 'en/dict_bbn',
);

has model_path => (
    is => 'ro',
    isa => 'Str',
    default => 'data/models/simple_ner',
);

has nested => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    documentation => 'Allow marking nested named entities?',
);

# $type_of{New York} == 'GPE:CITY'
has _type_of => (is=>'rw');

# $seen{New} == 8
# This means that longest entity starting with New has 8 tokens
# (it is "New York State Department of Taxation and Finance").
has _seen => (is=>'rw');

sub process_start {
    my ($self) = @_;
    my ($filename) = $self->require_files_from_share($self->model_path . '/' . $self->model_name);
    my (%seen, %type_of);
    open my $F, '<:utf8', $filename;
    while (<$F>) {
        my ($phrase, $type) = split /\t/, $_;
        $type_of{$phrase} = $type;
        my @tokens = split / /, $phrase;
        my $n = $seen{$tokens[0]};
        if (!$n or $n < @tokens){
            $seen{$tokens[0]} = scalar @tokens;
        }
    }
    $self->_set_type_of(\%type_of);
    $self->_set_seen(\%seen);
    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    # skip empty sentence
    return if !@anodes;

    # Create new n-tree
    my $n_root = $zone->has_ntree() ? $zone->get_ntree() : $zone->create_ntree();

    # The real work
    my $seen = $self->_seen;
    my $type_of = $self->_type_of;
    my @forms = map {$_->form} @anodes;
    my $i = -1;
    while ($i < $#anodes){
        $i++;
        my $n = $seen->{$forms[$i]};
        next if !$n;
        if ($i+$n-1 > $#forms){
            $n = $#forms - $i + 1;
        }
        LENGTH:
        for my $length (reverse 0 .. $n - 1){
            my $phrase = join ' ', @forms[$i .. $i+$length];
            my $type = $type_of->{$phrase};
            if ($type){
                my $n_node = $n_root->create_child(ne_type => $type);
                $n_node->set_anodes(@anodes[$i .. $i+$length]);
                if (!$self->nested){
                    $i += $length;
                    last LENGTH;
                }
            }
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2N::SimpleNER

=head1 DESCRIPTION

Named entity recognition based on dictionary (model) with three columns

 phrase \t type \t number_of_occurences

where the last column is optional.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

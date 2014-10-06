package Treex::Block::Misc::AbstractDialogueSlots;

use Moose;
use Treex::Core::Common;
use List::Util 'reduce';

extends 'Treex::Core::Block';

has 'abstraction_file' => ( isa => 'Str', is => 'rw', required => 1 );

has 'abstractions' => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );

has 'slots' => ( isa => 'Str', is => 'rw', required => 1 );

has 'slots_set' => (
    isa     => 'HashRef',
    is      => 'rw',
    lazy    => 1,
    default => sub { my %h = map { $_ => 1 } split /[, ]+/, $_[0]->slots; return \%h },
);

# Taken from http://www.perlmonks.org/?node_id=1070950
sub minindex {
    my @x = @_;
    reduce { $x[$a] < $x[$b] ? $a : $b } 0 .. $#_;
}

sub process_start {
    my ($self) = @_;

    open( my $fh, '<:utf8', ( $self->abstraction_file ) );
    while ( my $line = <$fh> ) {
        chomp $line;
        push @{ $self->abstractions }, $line;
    }
    close($fh);
}

sub process_zone {
    my ( $self, $zone ) = @_;

    my @anodes = $zone->get_atree()->get_descendants( { ordered => 1 } );

    my @abstrs = split "\t", shift @{ $self->abstractions };
    
    foreach my $abstr (@abstrs) {
        my ( $slot, $val, $from, $to ) = ( $abstr =~ /^([^=]*)=("[^"]*"|[^:]+):([0-9]+)-([0-9]+)$/ );
        
        # skip slots that shouldn't be abstracted
        if ( $self->slots_set and not defined( $self->slots_set->{$slot} ) ) {
            next;
        }
        # get t-nodes that reference the slot's span in the a-tree
        my @tnodes = map { $_->get_referencing_nodes('a/lex.rf') } @anodes[ $from .. $to - 1 ];
        if (!@tnodes){            
            log_warn('NO TNODES: ' . $zone->sentence() . ' ' . $zone->get_atree()->id . ' ' . $abstr);
            next;
        }
        # merge these t-nodes into one node and set its t-lemma to "X-slotname"
        my $top_tnode = $tnodes[ minindex map { $_->get_depth() } @tnodes ];
        my @other_tnodes = grep { $_ != $top_tnode } @tnodes;
        foreach my $other_tnode (@other_tnodes) {
            $top_tnode->add_aux_anodes( $other_tnode->get_anodes() );
            map { $_->set_parent($top_tnode) } $other_tnode->get_children();
            $other_tnode->remove();            
        }
        $top_tnode->set_t_lemma( 'X-' . $slot );
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Misc::AbstractDialogueSlots

=head1 DESCRIPTION

A helper block for the Tgen generator for spoken dialogue systems. Given analyzed sentences
corresponding to dialogue acts along with token ranges that should be replaced by a default
placeholder, it removes the t-nodes corresponding to these token ranges and replaces
them with one placeholder t-node.

=head1 PARAMETERS

=over

=item abstraction_file

Path to the file that contains token ranges to be replaced (ranges in format "slot:beginning-end",
separated by spaces, one sentence per line).

=item slots

Slots that should be affected by the replacing (some slots, e.g., with a small amount of values,
may be left out). 

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


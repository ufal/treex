package Treex::Block::Misc::DeabstractDialogueSlots;

use Moose;
use Treex::Core::Common;
use List::Util 'reduce';

extends 'Treex::Core::Block';

has 'abstraction_file' => ( isa => 'Str', is => 'rw', required => 1 );

has '_abstractions' => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );

has 'xs_instead' => ( isa => 'Bool', is => 'rw', default => 0 );


sub process_start {
    my ($self) = @_;

    open( my $fh, '<:utf8', ( $self->abstraction_file ) );
    while ( my $line = <$fh> ) {
        chomp $line;
        push @{ $self->_abstractions }, $line;
    }
    close($fh);
}

sub _get_next_abstraction {
    my ($self) = @_;
    my %abstr_set = ();

    foreach my $abstr ( split /\t/, shift @{ $self->_abstractions } ) {
        my ( $slot, $value ) = ( $abstr =~ /^([^=]*)=("[^"]*"|[^:]+):[0-9]+-[0-9]+$/ );
        if ( not defined( $abstr_set{$slot} ) ) {
            $abstr_set{$slot} = [];
        }
        push @{ $abstr_set{$slot} }, $value;
    }
    return \%abstr_set;
}

sub process_ttree {
    my ( $self, $troot ) = @_;
    my $abstr = $self->_get_next_abstraction();
    
    foreach my $tnode ( grep { $_->t_lemma =~ /^X-[a-z_]+$/ } $troot->get_descendants( { ordered => 1 } ) ) {
        my ($slot) = ( $tnode->t_lemma =~ /^X-(.*)$/ );
        my $value = 'X';
        if (!$self->xs_instead){
            $value = shift @{ $abstr->{$slot} };
            push @{ $abstr->{$slot} }, $value;
            $value =~ s/^["']//;
            $value =~ s/["']$//;
            $value =~ s/ /_/g;
        }
        $tnode->set_t_lemma($value);
    }

}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Misc::DeabstractDialogueSlots

=head1 DESCRIPTION

A helper block for Tgen generator – filling in concrete values into placeholders for
the individual dialogue slots.

=head1 PARAMETERS

=over

=item abstraction_file

Path to the file that contains token ranges to be replaced (ranges in format "slot:beginning-end",
separated by spaces, one sentence per line).

=item xs_instead

Replace all the de-abstracted names with a generic 'X' instead of the actual value.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


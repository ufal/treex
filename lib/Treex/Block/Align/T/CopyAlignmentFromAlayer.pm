package Treex::Block::Align::T::CopyAlignmentFromAlayer;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has 'to_language' => ( isa => 'Treex::Type::LangCode', is => 'ro', lazy_build => 1 );
has 'to_selector' => ( isa => 'Str',      is => 'ro', default => '' );

sub _build_to_language {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->to_language && $self->selector eq $self->to_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}

sub process_ttree {
    my ( $self, $troot ) = @_;

    my $to_troot = $troot->get_bundle->get_tree( $self->to_language, 't', $self->to_selector );

    # delete previously made links
    foreach my $tnode ( $troot->get_descendants ) {
        $tnode->set_attr( 'alignment', [] );
    }

    my %a2t;
    foreach my $to_tnode ( $to_troot->get_descendants ) {
        my $to_anode = $to_tnode->get_lex_anode;
        next if not $to_anode;
        $a2t{$to_anode} = $to_tnode;
    }

    foreach my $tnode ( $troot->get_descendants ) {
        my $anode = $tnode->get_lex_anode;
        next if not $anode;
        my ( $nodes, $types ) = $anode->get_aligned_nodes();
        foreach my $i ( 0 .. $#$nodes ) {
            my $to_tnode = $a2t{ $$nodes[$i] } || next;
            $tnode->add_aligned_node( $to_tnode, $$types[$i] );
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::T::CopyAlignmentFromAlayer

=head1 DESCRIPTION

This projects the tree alignment on a-layer to the corresponding t-layer trees.

=head1 PARAMETERS

=item C<language>

The current language. This parameter is required.

=item C<to_language>

The target (reference) language for the alignment. Defaults to current C<language> setting. 
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.

=item C<to_selector>

The target (reference) selector for the alignment. Defaults to current C<selector> setting.
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

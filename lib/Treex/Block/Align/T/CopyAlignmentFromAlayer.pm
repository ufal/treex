package Treex::Block::Align::T::CopyAlignmentFromAlayer;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;

subtype 'AlignTypes' => as 'HashRef[Bool]';
coerce 'AlignTypes' => from 'Str' => via { my %hash = map { $_ => 1 } (split /\|/, $_); \%hash };

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has 'to_language' => ( isa => 'Treex::Type::LangCode', is => 'ro', lazy_build => 1 );
has 'to_selector' => ( isa => 'Str',      is => 'ro', default => '' );

has 'del_prev_align' => ( isa => 'Bool', is => 'ro', default => 1, required => 1 );

has 'align_type' => ( isa => 'AlignTypes', is => 'ro', coerce => 1, default => sub { {} } );

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
    if ($self->del_prev_align) {
        foreach my $tnode ( $troot->get_descendants ) {
            $tnode->set_attr( 'alignment', [] );
        }
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
        my ( $nodes, $types ) = $anode->get_directed_aligned_nodes();
        foreach my $i ( 0 .. $#$nodes ) {
            next if (keys %{$self->align_type} && !$self->align_type->{$types->[$i]});
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

=over

=item C<language>

The current language. This parameter is required.

=item C<to_language>

The target (reference) language for the alignment. Defaults to current C<language> setting. 
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.

=item C<to_selector>

The target (reference) selector for the alignment. Defaults to current C<selector> setting.
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.

=item C<del_prev_align>

Delete previous alignment links coming from the source side given by C<language> and C<selector>.
Default = 1.

=item C<align_type>

Copy only the alignment links of types specified by this parameter. The C<align_type> can be
specified as a '|' delimited string of alignment types. If the string is empty, no restriction
on types to be copied is given.
Internally, the C<align_type> is represented as a hash-ref of bools indexed by alignemnt types
to easily check whether a link should be copied or not.

=back

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009-2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

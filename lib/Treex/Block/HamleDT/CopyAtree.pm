package Treex::Block::A2A::CopyAtree;

use Moose;
use Treex::Core::Common;
use Treex::Block::Align::AlignSameSentence;

extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', lazy_build => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );
has 'flatten'         => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'align'           => ( is       => 'rw', isa => 'Bool', default => 0 );

# alignment block
has '_aligner' => ( is => 'rw', isa => 'Object' );

sub _build_source_selector {
    my ($self) = @_;
    return $self->selector;
}

sub _build_source_language {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->source_language && $self->selector eq $self->source_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }

    # initialize alignment block if needed
    if ( $self->align ) {
        $self->_set_aligner(
            Treex::Block::Align::AlignSameSentence->new(
                language    => $self->language,
                selector    => $self->selector,
                to_selector => $self->source_selector,
                to_language => $self->source_language,
                layer       => 'a'
                )
        );
    }
}

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $source_zone = $bundle->get_zone( $self->source_language, $self->source_selector );
    my $source_root = $source_zone->get_atree;

    my $target_zone = $bundle->get_or_create_zone( $self->language, $self->selector );
    my $target_root = $target_zone->create_atree();

    copy_subtree( $source_root, $target_root );

    if ( $self->flatten ) {
        foreach my $node ( $target_root->get_descendants ) {
            $node->set_parent($target_root);
            $node->set_is_member();
        }
    }

    if ( $self->align ) {
        $self->_aligner->process_zone($target_zone);
    }
}

sub copy_subtree {
    my ( $source_root, $target_root ) = @_;

    $source_root->copy_atree($target_root);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CopyAtree

=head1 DESCRIPTION

This block copies analytical tree into another zone.

Trees are made flat if the switch C<flatten=1> is used. The new tree is aligned to the old one if
the switch C<align> is set to 1.

=head1 PARAMETERS

=item C<language>

The current language. This parameter is required.

=item C<source_language>

The target (reference) language for the alignment. Defaults to current C<language> setting.
The C<source_language> and C<source_selector> must differ from C<language> and C<selector>.

=item C<source_selector>

The target (reference) selector for the alignment. Defaults to current C<selector> setting.
The C<source_language> and C<source_selector> must differ from C<language> and C<selector>.

=item C<flatten>

If this parameter is set, the trees are made flat (i.e. all inner nodes are set as direct children
of the root).

=item C<align>

If this parameter is set, the target trees are aligned to the source ones.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

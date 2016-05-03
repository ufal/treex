package Treex::Block::A2A::ProjectCase;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Text::Unidecode;

has 'source_language' => ( is => 'rw', isa => 'Str', default => 'en' );
has 'source_selector' => ( is => 'rw', isa => 'Str', default => '' );
has 'ignore_diacritics' => ( is => 'rw', isa => 'Bool', default => 0 );

sub lcsf {
    my ($self, $anode) = @_;

    if ($self->ignore_diacritics) {
        return unidecode(lc $anode->form);
    } else {
        return lc $anode->form;
    }
}

sub process_anode {
    my ( $self, $anode ) = @_;

    my $source_root = $anode->get_bundle->get_tree($self->source_language, 'a', $self->source_selector);
    my @aligned = grep { $self->lcsf($_) eq $self->lcsf($anode) } $source_root->get_descendants();
    if (@aligned == 1) {
        my $source_anode = $aligned[0];
        if ($source_anode->form ne $anode->form && $source_anode->ord != 1 && $anode->ord != 1) {
            log_info("Changing " . $anode->form . " to " . $source_anode->form);
            $anode->set_form($source_anode->form);
        }
    }

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::ProjectCase -- project case froum source to target

=head1 DESCRIPTION

Change casing of each token to match a corresponding source token casing (set C<source_language> and C<source_selector> sppropriately).
A corresponding token is a token with identical form (ignoring case differences, of course).
If C<ignore_diacritics> is set to C<1>, the token matching ignores not only case but also diacritics.

Useful for post-processing Moses translations.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

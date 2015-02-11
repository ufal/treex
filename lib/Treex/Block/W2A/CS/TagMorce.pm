package Treex::Block::W2A::CS::TagMorce;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has _tagger => ( is => 'rw' );

use Morce::Czech;
use Treex::Tool::Transliteration::DowngradeUTF8forISO2;

sub BUILD {
    my ($self) = @_;
    return;
}

sub process_start {
    my $self = shift;

    $self->_set_tagger( Morce::Czech->new() );

    return;
}

Readonly my $max_word_length => 45;

sub process_atree {
    my ( $self, $atree ) = @_;

    my @a_nodes = $atree->get_descendants( { ordered => 1 } );
    my @forms = map { Treex::Tool::Transliteration::DowngradeUTF8forISO2::downgrade_utf8_for_iso2( $_->form ) } @a_nodes;

    my (@prefs, @sufs); # if needed, strip parts of words for tagging, store them and return to lemmas

    foreach my $form (@forms){
        my ($pref, $suf) = ('', $form);

        # avoid words > $max_word_length chars; Morce segfaults, take the suffix
        if (length($form) > $max_word_length){
            $pref = substr($form, 0, length($form) - $max_word_length);
            $suf = substr($form, -$max_word_length, $max_word_length);
        }
        # avoid words that contain dashes, take just what's after the dash (exclude very short words to prevent clashing
        # with a preposition, exclude shorter uppercase words (usually abbreviations), exclude "on-line" which is analyzed
        # correctly only together)
        if ( $suf !~ /^on-line/i
            && ($suf =~ m/[^\p{Upper}-]/ || $suf =~ m/^\p{Upper}{7,}/ || $suf =~ m/\p{Upper}{7,}$/)
            && $suf =~ m/^(.*)-([^-]{3,})$/ ){

            $pref .= $1 . '-';
            $suf = $2;
        }

        push @prefs, $pref;
        push @sufs, $suf;
    }

    # get tags and lemmas
    # Morče works with sentences of limited size. Avoid submitting long sentences.
    my $max_sentence_size = 500;
    my ($tags_rf, $lemmas_rf);
    my @tags;
    my @lemmas;
    if ( scalar(@sufs) > $max_sentence_size ) {
        my $n_parts = scalar(@sufs) / $max_sentence_size + 1;
        for ( my $i = 0; $i < $n_parts; $i++ ) {
            my $j0 = $i * $max_sentence_size;
            my $j1 = ($i + 1) * $max_sentence_size - 1;
            $j1 = $#sufs if($j1>$#sufs);
            my @sufs_part = @sufs[$j0..$j1];
            my ($tags_rf_part, $lemmas_rf_part) = $self->_tagger->tag_sentence( \@sufs_part );
            my $nf = scalar(@sufs_part);
            my $nt = scalar(@{$tags_rf_part});
            my $nl = scalar(@{$lemmas_rf_part});
            if($nt != $nf || $nl != $nf) {
                log_fatal("Number of tags and/or lemmas in tagged part differs from number of tokens. TOKENS: $nf; TAGS: $nt; LEMMAS: $nl.");
            }
            push( @tags, @{$tags_rf_part} );
            push( @lemmas, @{$lemmas_rf_part} );
        }
        $tags_rf = \@tags;
        $lemmas_rf = \@lemmas;
    }
    else {
        ($tags_rf, $lemmas_rf) = $self->_tagger->tag_sentence( \@sufs );
    }
    if ( @$tags_rf != scalar(@forms) || @$lemmas_rf != scalar(@forms) ) {
        my $nf = scalar(@forms);
        my $nt = scalar(@{$tags_rf});
        my $nl = scalar(@{$lemmas_rf});
        log_fatal "Different number of tokens, tags and lemmas. TOKENS: $nf, TAGS: $nt, LEMMAS: $nl.";
    }

    # fill tags
    foreach my $a_node ( @a_nodes ) {
        $a_node->set_tag( shift @$tags_rf );
        my $gotlemma = shift @$lemmas_rf;
        my $pref = shift @prefs; # return the previously stripped part, if applicable

        $a_node->set_lemma( $pref . $gotlemma );
    }

    return 1;
}

1;

__END__

=pod

=over

=item Treex::Block::W2A::CS::TagMorce

Each node in analytical tree is tagged using C<Morce::Czech> tagger.
Lemmata are also assigned.

=back

=cut

# Copyright 2011, 2012 David Mareček, Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README

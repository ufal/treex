package Treex::Block::W2A::CS::TagMorce;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has _tagger => ( is => 'rw' );

use Morce::Czech;
use DowngradeUTF8forISO2;

sub BUILD {
    my ($self) = @_;

    $self->_set_tagger( Morce::Czech->new() );

    return;
}

Readonly my $max_word_length => 45;

sub process_atree {
    my ( $self, $atree ) = @_;

    my @a_nodes = $atree->get_descendants( { ordered => 1 } );
    my @forms = map { DowngradeUTF8forISO2::downgrade_utf8_for_iso2( $_->form ) } @a_nodes;
        
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
    my ( $tags_rf, $lemmas_rf ) = $self->_tagger->tag_sentence( \@sufs );
    if ( @$tags_rf != @forms || @$lemmas_rf != @forms ) {
        log_fatal "Different number of tokens, tags and lemmas. TOKENS: @forms, TAGS: @$tags_rf, LEMMAS: @$lemmas_rf.";
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

# Copyright 2011 David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README

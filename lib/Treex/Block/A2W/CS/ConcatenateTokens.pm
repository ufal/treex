package Treex::Block::A2W::CS::ConcatenateTokens;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $a_root   = $bundle->get_tree('TCzechA');
    my $sentence = join " ",
        grep { !/#[A-Z]/ and !/^\-[A-Z]{3}\-$/ }
        map { $_->form || '' }
        $a_root->get_descendants( { ordered => 1 } );

    $sentence =~ s/ +/ /g;
    $sentence =~ s/ ([,.?:;])/$1/g;
    $sentence =~ s/(["“])\./\.$1/g;
    $sentence =~ s/ “/“/g;
    $sentence =~ s/„ /„/g;

    $sentence =~ s/([\-\"„;:,]),/$1/g;          # !!! tohle by chtelo udelat poradne a umazavat uz a-uzly
    $sentence =~ s/ ?([\.,]) ?([“"])/$1$2/g;    # mazani mezer kolem interpunkce
    $sentence =~ s/ se by / by se /g;             # !!! na prerovnani klitik bude potreba samostatny blok
    $sentence =~ s/ by že / že by /g;           # !!! na prerovnani klitik bude potreba samostatny blok

    $sentence =~ s/ -- / - /g;

    $sentence =~ s/ rocích/ letech/g;
    $sentence =~ s/(v|V) roku/$1 roce/g;
    $sentence =~ s/_/ /g;                         # !!! tohle by se nemelo stavat
    $sentence =~ s/ US / USA /g;

    # zavorky
    $sentence =~ s/,?\(,? ?/\(/g;
    $sentence =~ s/ ?,? ?\)/\)/g;

    # (The whole sentence is in parenthesis).
    # (The whole sentence is in parenthesis.)
    if ( $sentence =~ /^\(/ ) {
        $sentence =~ s/\)\./.)/;
    }

    $sentence =~ s/&#241;/ň/g;    # "ñ" is encoded as &#241; in translation dict

    $bundle->set_attr( 'czech_target_sentence', $sentence );
    return;
}

1;

=over

=item Treex::Block::A2W::CS::ConcatenateTokens

Creates the target sentence string simply by concatenation of word forms from TCzechA nodes
(the only remaining non-triviality is spacing around punctuation marks).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

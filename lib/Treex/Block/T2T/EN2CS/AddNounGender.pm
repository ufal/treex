package Treex::Block::T2T::EN2CS::AddNounGender;
use utf8;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

use CzechMorpho;
my $analyzer = CzechMorpho::Analyzer->new();

my %gender_tag2grammateme = (
    'M' => 'anim',
    'I' => 'inan',
    'F' => 'fem',
    'N' => 'neut',
);

# existuji slova s jinym rodem v sg a v pl: dite, knize, hrabe oko ucho oblak  # str. 40, Mluvnice II
#!!!! doresit knize, hrabe, oko, ucho
my %gender_in_plural = (
    'dítě' => 'F'
);

my %GENDER_FOR = (sto=>'N', tisíc=>'I', milion=>'I', milión=>'I', miliarda=>'F',
                  # !!! hack, nez se to vyresi obecneji pro vsechny mistni pojmenovane entity:
                  york=>'I',
 );

sub process_ttree {
    my ( $self, $t_root ) = @_;

    # For all t-nodes with no gender ...
    # (named entities have gender already filled)
    foreach my $t_node ( grep {!defined $_->get_attr('gram/gender')} $t_root->get_descendants() ) {
        my $gender  = get_noun_gender( $t_node );
        if ( defined $gender ) {
            $t_node->set_attr( 'gram/gender', $gender_tag2grammateme{$gender} );
        }
    }
    return;
}

sub get_noun_gender {
    my ($t_node) = @_;
    my $t_lemma = $t_node->t_lemma;

    # Some numerals (sempos = n.quant.def) should have gender 
    my $gender = $GENDER_FOR{$t_lemma};
    return $gender if $gender;
    
    # Now we are interested only in denotative nouns (but sempos is not reliable yet)
    return undef if ($t_node->formeme || '') !~ /^n/;

    # Some nouns have different gender in plural
    my $number = $t_node->get_attr('gram/number');
    if ( defined $number && $number eq 'pl') {
        $gender = $gender_in_plural{$t_lemma};
        return $gender if $gender;
    }

    # For most cases use CzechMorpho::Analyze
    ($gender) = map { /^..(.)/; $1 } grep {/^NN..1/} map { $_->{tag} } $analyzer->analyze($t_lemma);

    # if t_lemma was incorrectly lowercased
    if (not $gender) {
	($gender) = map { /^..(.)/; $1 } grep {/^NN..1/} map { $_->{tag} } $analyzer->analyze(ucfirst($t_lemma));
    }

    return $gender if $gender && $gender =~ /[MIFN]/;

    return undef;
}

1;

=over

=item Treex::Block::T2T::EN2CS::AddNounGender

Semantic denotative nouns in TCzechT are genderless after cloning
(i.e., without the value of attribute C<gram/gender>), because there is no
gender in English POS noun tags. This block fills the gender
grammateme according to the morphological tag of the translated (Czech)
noun t_lemma. Node that special treatment is neccessary because
of word with different gender in singular and plural (such as dite, knize, hrabe).

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

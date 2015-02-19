package Treex::Block::T2T::EN2CS::AddNounGender;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use Treex::Tool::Lexicon::Generation::CS;
use Treex::Tool::LM::MorphoLM;
use Treex::Tool::LM::FormInfo;

has morphoLM  => ( is => 'rw' );
has generator => ( is => 'rw' );

sub BUILD {
    my $self = shift;

    return;
}

sub process_start {
    my ($self) = @_;
    $self->set_morphoLM( Treex::Tool::LM::MorphoLM->new() );
    $self->set_generator( Treex::Tool::Lexicon::Generation::CS->new() );
    return;
}

my %gender_tag2grammateme = (
    'M' => 'anim',
    'I' => 'inan',
    'F' => 'fem',
    'N' => 'neut',
);

# Several Czech nouns have different gender in singular and plural.
# For kníže, hrabě,... the regular (M) gender is more common now (Mluvnice II, str. 40).
my %SG_PL_GENDER_FOR = (
    'dítě' => 'NF',
    'oblak'  => 'IN',
    'oko'    => 'NF',
    'ucho'   => 'NF',
);

my %GENDER_FOR = (sto=>'N', tisíc=>'I', milion=>'I', milión=>'I', miliarda=>'F',
                  # !!! hack, nez se to vyresi obecneji pro vsechny mistni pojmenovane entity:
                  york=>'I',
);

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # For all t-nodes with no gender ...
    # (named entities have gender already filled)
    return if ($tnode->gram_gender);
    my $gender  = $self->get_noun_gender( $tnode );
    if ( defined $gender ) {
        $tnode->set_gram_gender( $gender_tag2grammateme{$gender} );
    }
   return;
}

sub get_noun_gender {
    my ($self, $t_node) = @_;
    my $t_lemma = $t_node->t_lemma;

    # Some numerals (sempos = n.quant.def) should have gender 
    my $gender = $GENDER_FOR{$t_lemma};
    return $gender if $gender;
    
    # Now we are interested only in denotative nouns (but sempos is not reliable yet)
    return undef if ($t_node->formeme || '') !~ /^n/;

    # Some nouns have different gender in plural
    if ( my $sg_pl_gender = $SG_PL_GENDER_FOR{$t_lemma}) {
        if (($t_node->gram_number|| '') eq 'pl'){
            $sg_pl_gender =~ s/^.//;
        } else {
            $sg_pl_gender =~ s/.$//;
        }
        return $sg_pl_gender;
    }

    # If the source lemma was uppercase, MorphoLM should look also for uppercase
    my $en_tnode = $t_node->src_tnode;
    my $args = {};
    if ($en_tnode && $en_tnode->t_lemma =~ /^\p{IsUpper}/){
        $args = {lowercased_lemma=>1};
    }

    # Try MorphoLM, fallback to Jan Hajic's morphology (hack incorrectly lowercased lemmas)
    log_debug('CALLING ' . $t_node->get_address() . ' / ' . $t_lemma, 1);
    my $form_info =    
        $self->morphoLM->best_form_of_lemma( $t_lemma, '^NN..[1X]', $args )
     || $self->generator->best_form_of_lemma( $t_lemma, '^NN..[1X]' )
     || $self->generator->best_form_of_lemma( ucfirst $t_lemma, '^NN..[1X]' );

    if ($form_info) {
        ($gender) = $form_info->get_tag =~ /^..(.)/;
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

# Copyright 2008-2012 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

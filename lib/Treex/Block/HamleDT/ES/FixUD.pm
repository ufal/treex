package Treex::Block::HamleDT::ES::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_morphology($root);
}



#------------------------------------------------------------------------------
# Fixes known issues in part-of-speech tags and features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    my @pron2propn = qw(Coordenadas Creo Crepúsculo Don Escándalo Greybull Mazomanie Mé Nación OCDE Pinauto Siemens Volkswagen);
    my @pron2noun = qw(bolchevique botella célula do empresaria mella organismos paella resto sello vuvuzelas);
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $iset = $node->iset();
        # The common gender should not be used in Spanish.
        # It should be empty, which means any gender, which in case of Spanish is masculine or feminine.
        if($iset->is_common_gender())
        {
            $iset->set('gender', '');
        }
        # There are several issues with pronouns and determiners.
        if($iset->prontype() ne '' && $iset->is_adjective())
        {
            if($form =~ m/^(el|la|los|las)$/i)
            {
                $node->set_lemma('el');
                $iset->set('prontype', 'art');
                $iset->set('definiteness', 'def');
            }
            elsif($form =~ m/^un([oa]s?)?$/i)
            {
                $node->set_lemma('uno');
                $iset->set('prontype', 'art');
                $iset->set('definiteness', 'ind');
            }
        }
        elsif($iset->prontype() ne '' && $iset->is_noun())
        {
            # Some words are tagged PRON instead of PROPN.
            if(any {$_ eq $form} (@pron2propn))
            {
                $iset->clear('prontype');
                $iset->set('nountype', 'prop');
            }
            elsif(any {$_ eq $form} (@pron2noun))
            {
                $iset->clear('prontype');
            }
            elsif($form =~ m/^(medio|natural|último|único)$/i)
            {
                $iset->clear('prontype');
                $iset->set('pos', 'adj');
            }
            elsif($form =~ m/^(1|dos|tres)$/i)
            {
                $iset->clear('prontype');
                $iset->set('pos', 'num');
                $iset->set('numtype', 'card');
            }
            elsif($form =~ m/^(aparece|desapercibida|está|puedes|ser)$/i)
            {
                $iset->clear('prontype');
                $iset->set('pos', 'verb');
            }
            elsif($form =~ m/^(allí|cuando|donde)$/i)
            {
                $iset->set('pos', 'adv');
            }
            elsif($form =~ m/^(al?)$/)
            {
                $iset->clear('prontype');
                $iset->set('pos', 'adp');
            }
            elsif($form eq 'si')
            {
                $iset->clear('prontype');
                $iset->set('pos', 'conj');
                $iset->set('conjtype', 'sub');
            }
            elsif($form eq 'sí')
            {
                $iset->clear('prontype');
                $iset->set('pos', 'int');
            }
            # The rest is pronouns but we have to figure out the type of pronoun.
            else
            {
                if($form =~ m/^(yo|me|mí|nosotros|nos|tú|te|ti|vosotros|vos|os|usted|ustedes|él|ella|ello|le|lo|la|ellos|ellas|les|los|las|se)$/i)
                {
                    $iset->set('prontype', 'prs');
                    # For some reason, the second person plural pronouns have wrong lemmas (os:os, vos:vo, vosotros:vosotro).
                    if($form =~ m/^(vosotros|vos|os)$/i)
                    {
                        # The system used in the Spanish corpus: every person uses its own lemma. Just one lemma for both numbers and all forms in that person.
                        $node->set_lemma('tú');
                    }
                    # Some of the non-nominative personal pronouns got lemma "el" instead of "él".
                    # The lemmatizer mistook them for definite articles.
                    elsif($form =~ m/^(la|las|los)$/)
                    {
                        $node->set_lemma('él');
                    }
                }
                elsif($form =~ m/^(mi|nuestr[oa]s?|tu|vuestr[oa]s?|su|suy[oa]s?)$/i)
                {
                    $iset->set('prontype', 'prs');
                    $iset->set('poss', 'poss');
                }
                elsif($form =~ m/^(aquel(l[oa]s?)?|aquél|[eé]st?[aeo]s?|mism[oa]s?|tal(es)?)$/i)
                {
                    $iset->set('prontype', 'dem');
                }
                elsif($form =~ m/^(tant[oa]s?)$/i)
                {
                    $iset->set('prontype', 'dem');
                    $iset->set('numtype', 'card');
                }
                elsif($form =~ m/^(tod[oa]s?)$/i)
                {
                    $iset->set('prontype', 'tot');
                }
                elsif($form =~ m/^(amb[oa]s)$/i)
                {
                    $iset->set('prontype', 'tot');
                    $iset->set('numtype', 'card');
                }
                elsif($form =~ m/^(nada|nadie|niguna|ninguna|ninguno|ningún)$/i)
                {
                    $iset->set('prontype', 'neg');
                }
                elsif($form =~ m/^(cu[aá]l(es)?|qu[eé]|qui[eé]n(es)?)$/i)
                {
                    $iset->set('prontype', 'int', 'rel'); ###!!! should be int|rel
                }
                elsif($form =~ m/^(cuy[oa]s?)$/i)
                {
                    $iset->set('prontype', 'int'); ###!!! should be int|rel
                    $iset->set('poss', 'poss');
                }
                elsif($form =~ m/^(cu[aá]nt[oa]s?)$/i)
                {
                    $iset->set('prontype', 'int'); ###!!! should be int|rel
                    $iset->set('numtype', 'card');
                }
                elsif($form =~ m/^(bastantes?|demasiado|much[oa]s?|poc[oa]s?)$/i)
                {
                    $iset->set('prontype', 'ind');
                    $iset->set('numtype', 'card');
                }
                elsif($form =~ m/^(menos|más)$/i)
                {
                    $iset->set('prontype', 'ind');
                    $iset->set('numtype', 'card');
                    $iset->set('degree', 'cmp');
                }
                elsif($form =~ m/^(much[ií]simi?o)$/i)
                {
                    $iset->set('prontype', 'ind');
                    $iset->set('numtype', 'card');
                    $iset->set('degree', 'abs');
                }
                else # algo alguien alguna algunas alguno algunos cualquiera demás otra otras otro otros toda todas todo todos varias varios
                {
                    $iset->set('prontype', 'ind');
                }
            }
        } # is pronoun
    }
}



1;

=over

=item Treex::Block::HamleDT::ES::FixUD

This is a temporary block that should fix selected known problems in the Spanish UD 1.1 treebank.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

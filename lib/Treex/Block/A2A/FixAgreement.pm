package SCzechA_to_TCzechA::Fix_agreement_using_source;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

use LanguageModel::MorphoLM;
my $morphoLM = LanguageModel::MorphoLM->new();

use Lexicon::Generation::CS;
my $generator = Lexicon::Generation::CS->new();

my $fixcount = 0;

sub process_bundle {
    my ( $self, $bundle ) = @_;
    
    my $en_root = $bundle->get_tree('SEnglishA');
    my $a_root = $bundle->get_tree('TCzechA');

    # get alignment mapping
    my %en_counterpart;
    foreach my $en_node ($en_root->get_descendants) {
        my $links = $en_node->get_attr('m/align/links');
        next if !$links;
        $en_counterpart{$bundle->get_document->get_node_by_id($links->[0]->{'counterpart.rf'})->get_attr('ord')} = $en_node;
    }

    # agreement between subject and predicate
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($g->{afun} eq 'Pred' && $en_counterpart{$dep->get_attr('ord')} && $en_counterpart{$dep->get_attr('ord')}->afun eq 'Sb' && $g->{tag} =~ /^VB/ && $d->{tag} =~ /^[NP][^D]/ && $g->{num} ne $d->{num}) {
            my $num = $d->{num};
            $g->{tag} =~ s/^(...)./$1$num/;
            if ($d->{tag} =~ /^.......([123])/) {
                my $person = $1;
                $g->{tag} =~ s/^(.......)./$1$person/;
            }
            regenerate_node($gov, $g->{tag});
        }
    }

    # agreement between subject and past participle
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($en_counterpart{$dep->get_attr('ord')} && $en_counterpart{$dep->get_attr('ord')}->afun eq 'Sb' && $g->{tag} =~ /^Vp/ && $d->{tag} =~ /^[NP]/ && $dep->form !~ /^[Tt]o/ && ($g->{gen}.$g->{num} ne gn2pp($d->{gen}.$d->{num}))) {
#            print STDERR $en_counterpart{$dep->get_attr('ord')}->afun . "<<<\n" if defined $en_counterpart{$dep->get_attr('ord')};
            my $new_gn = gn2pp($d->{gen}.$d->{num});
            $g->{tag} =~ s/^(..)../$1$new_gn/;
            regenerate_node($gov, $g->{tag});
        }
    }

    # agreement between pasive and auxiliary verb 'to be'
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($g->{afun} eq 'Pred' && $d->{afun} eq 'AuxV' && $g->{tag} =~ /^Vs/ && $d->{tag} =~ /^Vp/ && ($g->{gen}.$g->{num} ne $d->{gen}.$d->{num})) {
            my $new_gn = $g->{gen}.$g->{num};
            $d->{tag} =~ s/^(..)../$1$new_gn/;
            regenerate_node($dep, $d->{tag});
        }
    }

    # agreement between verb and auxiliary 'to be'
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($d->{afun} eq 'AuxV' && $g->{tag} =~ /^Vf/ && $d->{tag} =~ /^VB/) {
            my $subject;
            foreach my $child ($gov->get_children()) {
                $subject = $child if $child->afun eq 'Sb';
            }
            next if !$subject;
            my $sub_num = substr($subject->tag, 3, 1);
            if ($sub_num ne $d->{num}) {
                $d->{tag} =~ s/^(...)./$1$sub_num/;
                regenerate_node($dep, $d->{tag});
            }
        }
    }

    # agreement between preposition and noun
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($g->{afun} eq 'AuxP' && $d->{afun} =~ /^(Atr)$/ && $g->{tag} =~ /^R/ && $d->{tag} =~ /^N/ && $g->{case} ne $d->{case}) {
            my $case = $g->{case};
            $d->{tag} =~ s/^(....)./$1$case/;
            regenerate_node($dep, $d->{tag});
#    print STiDERR $bundle->get_attr('czech_source_sentence')."\n";
#    print STDERR "AuxP-Atr fixed ".$dep->form." ".$gov->form."\n\n";
        }
    }

    # agreement between noun and adjective
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($d->{afun} eq 'Atr' && $g->{tag} =~ /^N/ && $d->{tag} =~ /^A/ && $g->{ord} > $d->{ord} && ($g->{gen}.$g->{num}.$g->{case} ne $d->{gen}.$d->{num}.$d->{case})) {
            my $new_gnc = $g->{gen}.$g->{num}.$g->{case};
            $d->{tag} =~ s/^(..).../$1$new_gnc/;
            regenerate_node($dep, $d->{tag});
        }
    }
    return;
}

sub get_form { 

    my ($lemma, $tag) = @_;

    $lemma =~ s/[-_].+$//; # ???

    $tag =~ s/^V([ps])[IF]P/V$1TP/;
    $tag =~ s/^V([ps])[MI]S/V$1YS/;
    $tag =~ s/^V([ps])(FS|NP)/V$1QW/;


    $tag =~ s/^(P.)FS/$1\[FHQTX\-\]S/;
    $tag =~ s/^(P.)F([^S])/$1\[FHTX\-\]$2/;
    $tag =~ s/^(P.)NP/$1\[NHQXZ\-\]P/;
    $tag =~ s/^(P.)N([^P])/$1\[NHXZ\-\]$2/;

    $tag =~ s/^(P.)I/$1\[ITXYZ\-\]/;
    $tag =~ s/^(P.)M/$1\[MXYZ\-\]/;
    $tag =~ s/^(P.+)P(...........)/$1\[DPWX\-\]$2/;
    $tag =~ s/^(P.+)S(...........)/$1\[SWX\-\]$2/;

    $tag =~ s/^(P.+)(\d)(..........)/$1\[$2X\]$3/;


    my $form = $morphoLM->best_form_of_lemma( $lemma, $tag );

    if (!$form) {
        my ($form_info) = $generator->forms_of_lemma( $lemma, { tag_regex => "^$tag" } );
        $form = $form_info->get_form() if $form_info;
    }
    if (!$form) {
        print STDERR "Can't find a word for lemma '$lemma' and tag '$tag'.\n";
    }

    return $form;
}


sub regenerate_node {
    my ($node, $new_tag) = @_;

    my $old_form = $node->form;
    my $new_form = get_form( $node->lemma, $new_tag );
    return if !defined $new_form;
    $new_form = ucfirst $new_form if $old_form =~ /^(\p{isUpper})/;
    $node->set_tag($new_tag);
    $node->set_form($new_form);

    return $new_form;
}


sub get_pair {
    my ($node) = @_;

    my $parent = $node->get_parent;
    while ($node->is_member && !$parent->is_root() && $parent->afun =~ /^(Coord|Apos)$/) {
        $parent = $parent->get_parent();
    }
    return undef if $parent->is_root();

    my $d_tag = $node->tag;
    my $g_tag = $parent->tag;
    $d_tag =~ /^..(.)(.)(.)/;
    my %d_categories = (tag => $d_tag, afun => $node->afun, ord => $node->get_attr('ord'), gen => $1, num => $2, case => $3);
    $g_tag =~ /^..(.)(.)(.)/;
    my %g_categories = (tag => $g_tag, afun => $parent->afun, ord => $parent->get_attr('ord'), gen => $1, num => $2, case => $3);

    return ($node, $parent, \%d_categories, \%g_categories);
}

sub gn2pp {
    my $gn = shift;
    $gn =~ s/[IF]P/TP/;
    $gn =~ s/[MI]S/YS/;
    $gn =~ s/(FS|NP)/QW/;
    return $gn;
}

sub add_children {
    my ($node, $queue) = @_;
    foreach my $child ($node->get_children()) {
        push @$queue, $child;
        add_children($child, $queue);
    }
}


1;


=over

=item SCzechA_to_TCzechA::Fix_agreement

Fixing grammatical agreement between subjects and predicates, prepositions and nouns, and nouns and adjectives in the tree TCzechA.
The tag is changed, then the word form is regenerated.

=back

=cut

# Copyright 2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

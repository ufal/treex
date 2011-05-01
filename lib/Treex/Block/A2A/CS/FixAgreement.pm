package Treex::Block::A2A::CS::FixAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has '+language'   => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', required => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );

use LanguageModel::MorphoLM;
my $morphoLM = LanguageModel::MorphoLM->new();

use Lexicon::Generation::CS;
my $generator = Lexicon::Generation::CS->new();

sub process_zone {
    my ( $self, $zone ) = @_;
    
    my $en_root = $zone->get_bundle->get_tree($self->source_language, 'a', $self->source_selector);
    my $a_root  = $zone->get_atree;

    # get alignment mapping
    my %en_counterpart;
    foreach my $en_node ($en_root->get_descendants) {
        my ($nodes, $types) = $en_node->get_aligned_nodes();
        if ($$nodes[0]) {
            $en_counterpart{$$nodes[0]} = $en_node;
        }
    }

    # agreement between subject and predicate
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($gov->afun eq 'Pred' && $en_counterpart{$dep} && $en_counterpart{$dep}->afun eq 'Sb' && $g->{tag} =~ /^VB/ && $d->{tag} =~ /^[NP][^D]/ && $g->{num} ne $d->{num}) {
            my $num = $d->{num};
            $g->{tag} =~ s/^(...)./$1$num/;
            if ($d->{tag} =~ /^.......([123])/) {
                my $person = $1;
                $g->{tag} =~ s/^(.......)./$1$person/;
            }
            logfix1($node, "subj-pred-agree");
            regenerate_node($gov, $g->{tag});
            logfix2($node);
        }
    }

    # agreement between subject and past participle
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($en_counterpart{$dep} && $en_counterpart{$dep}->afun eq 'Sb' && $g->{tag} =~ /^Vp/ && $d->{tag} =~ /^[NP]/ && $dep->form !~ /^[Tt]o/ && ($g->{gen}.$g->{num} ne gn2pp($d->{gen}.$d->{num}))) {
            my $new_gn = gn2pp($d->{gen}.$d->{num});
            $g->{tag} =~ s/^(..)../$1$new_gn/;
            logfix1($node, "subj-past-part-agree");
            regenerate_node($gov, $g->{tag});
            logfix2($node);
        }
    }

    # agreement between pasive and auxiliary verb 'to be'
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($gov->afun eq 'Pred' && $dep->afun eq 'AuxV' && $g->{tag} =~ /^Vs/ && $d->{tag} =~ /^Vp/ && ($g->{gen}.$g->{num} ne $d->{gen}.$d->{num})) {
            my $new_gn = $g->{gen}.$g->{num};
            $d->{tag} =~ s/^(..)../$1$new_gn/;
            logfix1($node, "pasiv-aux-be-agree");
            regenerate_node($dep, $d->{tag});
            logfix2($node);
        }
    }

    # agreement between verb and auxiliary 'to be'
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($dep->afun eq 'AuxV' && $g->{tag} =~ /^Vf/ && $d->{tag} =~ /^VB/) {
            my $subject;
            foreach my $child ($gov->get_children()) {
                $subject = $child if $child->afun eq 'Sb';
            }
            next if !$subject;
            my $sub_num = substr($subject->tag, 3, 1);
            if ($sub_num ne $d->{num}) {
                $d->{tag} =~ s/^(...)./$1$sub_num/;
                logfix1($node, "verb-aux-be-agree");
                regenerate_node($dep, $d->{tag});
                logfix2($node);
            }
        }
    }

    # agreement between preposition and noun
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($gov->afun eq 'AuxP' && $dep->afun =~ /^(Atr)$/ && $g->{tag} =~ /^R/ && $d->{tag} =~ /^N/ && $g->{case} ne $d->{case}) {
            my $doCorrect;
            #if there is an EN counterpart for $dep but it is not a preposition,
            #it means that the CS tree is probably incorrect
            #and the $gov prep does not belong to this $dep at all
            if ($en_counterpart{$dep}) {
                my ($enDep, $enGov, $enD, $enG) = get_pair($en_counterpart{$dep});
                if ($enGov and $enDep and $enGov->{afun} eq 'AuxP') {
                    $doCorrect = 1; #en_counterpart's parent is also a prep
                } else {
                    $doCorrect = 0; #en_counterpart's parent is not a prep
                }
            } else {
                $doCorrect = 1; #no en_counterpart
            }
            if ($doCorrect) {
                my $case = $g->{case};
                $d->{tag} =~ s/^(....)./$1$case/;
                logfix1($node, "prep-noun-agree");
                regenerate_node($dep, $d->{tag});
                logfix2($node);
            } #else do not correct
        }
    }

    # agreement between noun and adjective
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($dep->afun eq 'Atr' && $g->{tag} =~ /^N/ && $d->{tag} =~ /^A/ && $gov->ord > $dep->ord && ($g->{gen}.$g->{num}.$g->{case} ne $d->{gen}.$d->{num}.$d->{case})) {
            my $new_gnc = $g->{gen}.$g->{num}.$g->{case};
            $d->{tag} =~ s/^(..).../$1$new_gnc/;
            logfix1($node, "noun-adj-agree");
            regenerate_node($dep, $d->{tag});
            logfix2($node);
        }
    }
    
    # present continuous fix ("is working" translated as "je pracuje")
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        next if !$dep;
        if ($dep->{lemma} eq 'být' && $d->{tag} =~ /^VB/ && $g->{tag} =~ /^VB/ && $en_counterpart{$gov} && $en_counterpart{$gov}->{form} =~ /ing$/) {
            my $doCorrect;
            if ($en_counterpart{$dep}) {
                my ($enDep, $enGov, $enD, $enG) = get_pair($en_counterpart{$dep});
                if ($enGov and $enDep and $enGov->{form} =~ /ing$/) {
                    $doCorrect = 1;
                } else {
                    $doCorrect = 0;
                }
            } else {
                $doCorrect = 1;
            }
            if ($doCorrect) {
                #log1
                logfix1($node, "pres-cont");
                #set gov's tag to dep's tag (preserve negation)
                my $negation;
                if( substr ($g->{tag}, 10, 1) eq 'N' or substr ($d->{tag}, 10, 1) eq 'N' ) {
                    $negation = 'N';
                } else {
                    $negation = 'A';
                }
                my $tag = substr ($d->{tag}, 0, 10) . $negation . substr ($d->{tag}, 11);
                regenerate_node($gov, $tag);
                #move children under parent and remove
                my $parent = $dep->get_parent;
                foreach my $child ($dep->get_children) {
                    $child->set_parent($parent);
                }
                $dep->remove;
                #log2
                logfix2(($parent->get_children)[0]); #makes at least a little sense
            }
        }
    }

    return;
}

my $logfixmsg = '';
my $logfixold = '';
my $logfixnew = '';
my $logfixbundle = undef;

sub logfix1 {
    my $node = shift;
    my $mess = shift;
    my ($dep, $gov, $d, $g) = get_pair($node);
    
    $logfixmsg = $mess;
    $logfixbundle = $node->get_bundle;
    
    #original words pair
    if ($gov->ord < $dep->ord) {
        $logfixold = $gov->{form};
        $logfixold .= " ";
        $logfixold .= $dep->{form};
    } else {
    	$logfixold = $dep->{form};
    	$logfixold .= " ";
    	$logfixold .= $gov->{form};
    }
}

sub logfix2 {
    my $node = shift;
    if ($node) {
        my ($dep, $gov, $d, $g) = get_pair($node);
        #new words pair
        if ($gov->ord < $dep->ord) {
        	$logfixnew = $gov->{form};
        	$logfixnew .= " ";
        	$logfixnew .= $dep->{form};
        } else {
        	$logfixnew = $dep->{form};
        	$logfixnew .= " ";
        	$logfixnew .= $gov->{form};
    	}
    } else {
    	$logfixnew = '(removal)';
    }
    #output
    if ($logfixold ne $logfixnew) {
        if ($logfixbundle->get_zone( 'cs', 'FIXLOG' )) {
            my $sentence = $logfixbundle->get_or_create_zone( 'cs', 'FIXLOG' )->sentence . " {$logfixmsg: $logfixold -> $logfixnew}";
            $logfixbundle->get_zone( 'cs', 'FIXLOG' )->set_sentence($sentence);
        } else {
            my $sentence = "{$logfixmsg: $logfixold -> $logfixnew}";
            $logfixbundle->create_zone( 'cs', 'FIXLOG' )->set_sentence($sentence);
        }
    }
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
    return undef if $parent->is_root;

    my $d_tag = $node->tag;
    my $g_tag = $parent->tag;
    $d_tag =~ /^..(.)(.)(.)/;
    my %d_categories = (tag => $d_tag, gen => $1, num => $2, case => $3);
    $g_tag =~ /^..(.)(.)(.)/;
    my %g_categories = (tag => $g_tag, gen => $1, num => $2, case => $3);

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

=item Treex::Block::A2A::CS::FixAgreement

Fixing grammatical agreement between subjects and predicates, prepositions and nouns, and nouns and adjectives in the tree TCzechA.
The tag is changed, then the word form is regenerated.

=back

=cut

# Copyright 2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

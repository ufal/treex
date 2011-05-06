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

# this sub is to be to be redefined in child module
sub fix {
    die 'abstract sub fix() called';
    
    #sample of body of sub fix:

    my ($self, $dep, $gov, $d, $g, $en_hash) = @_;
    my %en_counterpart = %$en_hash;
    
    if (1) { #if something holds
	
        #do something here
	
	$self->logfix1($dep, "some change was made");
	$self->regenerate_node($gov, $g->{tag});
	$self->logfix2($dep);
    }
}

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

    #do the fix for each node
    foreach my $node ($a_root->get_descendants()) {
        my ($dep, $gov, $d, $g) = $self->get_pair($node);
        next if !$dep;
	$self->fix($dep, $gov, $d, $g, \%en_counterpart);
    }

    return;
}


# logging

my $logfixmsg = '';
my $logfixold = '';
my $logfixnew = '';
my $logfixbundle = undef;

sub logfix1 {
    my ($self, $node, $mess) = @_;
    my ($dep, $gov, $d, $g) = $self->get_pair($node);
    
    $logfixmsg = $mess;
    $logfixbundle = $node->get_bundle;
    
    if ($gov && $dep) {
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
    } else {
        $logfixold = '(undefined node)';
    }
}

sub logfix2 {
    my ($self, $node) = @_;
    if ($node) {
        my ($dep, $gov, $d, $g) = $self->get_pair($node);
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

    my ($self, $lemma, $tag) = @_;

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
    my ($self, $node, $new_tag) = @_;

    $node->set_tag($new_tag); #set even if !defined $new_form

    my $old_form = $node->form;
    my $new_form = $self->get_form( $node->lemma, $new_tag );
    return if !defined $new_form;
    $new_form = ucfirst $new_form if $old_form =~ /^(\p{isUpper})/;
    $node->set_form($new_form);

    return $new_form;
}


sub get_pair {
    my ($self, $node) = @_;

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
    my ($self, $gn) = @_;
    $gn =~ s/[IF]P/TP/;
    $gn =~ s/[MI]S/YS/;
    $gn =~ s/(FS|NP)/QW/;
    return $gn;
}

1;


=over

=item Treex::Block::A2A::CS::FixAgreement

Base class for grammatical errors fixing (common ancestor of all A2A::CS::Fix* modules).

A loop goes through all nodes in the analytical tree, gets their effective parent
 and their morphological categories and passes this data to the fix() sub.
In this module, the fix() has an empty implementation - it is to be redefined in children modules.

The fix() sub can make use of subs defined in this module.

If you find an error, you probably want to call the regenerate_node() sub.
The tag is changed, then the word form is regenerated.

To log changes that were made into the tree that was changed
(into the sentence in a zone cs_FIXLOG), call logfix1() before calling regenerate_node()
and logfix2() after calling regenerate_node().

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

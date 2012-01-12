package Treex::Block::A2A::CS::FixAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', required => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );

use LanguageModel::MorphoLM;
my $morphoLM = LanguageModel::MorphoLM->new();

use Treex::Tool::Lexicon::Generation::CS;
my $generator = Treex::Tool::Lexicon::Generation::CS->new();

# this sub is to be to be redefined in child module
sub fix {
    die 'abstract sub fix() called';

    #sample of body of sub fix:

    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    if (1) {    #if something holds

        #do something here

        $self->logfix1( $dep, "some change was made" );
        $self->regenerate_node( $gov, $g->{tag} );
        $self->logfix2($dep);
    }
}

sub process_zone {
    my ( $self, $zone ) = @_;

    my $en_root = $zone->get_bundle->get_tree( $self->source_language, 'a', $self->source_selector );
    my $a_root = $zone->get_atree;

    # get alignment mapping
    my %en_counterpart;
    foreach my $en_node ( $en_root->get_descendants ) {
        my ( $nodes, $types ) = $en_node->get_aligned_nodes();
        if ( $$nodes[0] ) {
            $en_counterpart{ $$nodes[0] } = $en_node;
        }
    }

    #do the fix for each node
    foreach my $node ( $a_root->get_descendants() ) {
	next if $node =~ 'Treex::Core::Node::Deleted';
        my ( $dep, $gov, $d, $g ) = $self->get_pair($node);
        next if !$dep;
        $self->fix( $dep, $gov, $d, $g, \%en_counterpart );
    }

    return;
}

# logging

my $logfixmsg    = '';
my $logfixold    = '';
my $logfixnew    = '';
my $logfixbundle = undef;

sub logfix1 {
    my ( $self, $node, $mess ) = @_;
    my ( $dep, $gov, $d, $g ) = $self->get_pair($node);

    $logfixmsg    = $mess;
    $logfixbundle = $node->get_bundle;

    if ( $gov && $dep ) {

        #original words pair
        if ( $gov->ord < $dep->ord ) {
            $logfixold = $gov->form;
            $logfixold .= "[";
            $logfixold .= $gov->tag;
            $logfixold .= "] ";
            $logfixold .= $dep->form;
            $logfixold .= "[";
            $logfixold .= $dep->tag;
            $logfixold .= "] ";
        }
        else {
            $logfixold = $dep->form;
            $logfixold .= "[";
            $logfixold .= $dep->tag;
            $logfixold .= "] ";
            $logfixold .= $gov->form;
            $logfixold .= "[";
            $logfixold .= $gov->tag;
            $logfixold .= "] ";
        }
    }
    else {
        $logfixold = '(undefined node)';
    }
}

sub logfix2 {
    my ( $self, $node ) = @_;
    if ($node) {
        my ( $dep, $gov, $d, $g ) = $self->get_pair($node);
        return if !$dep;

        #new words pair
        if ( $gov->ord < $dep->ord ) {
            $logfixnew = $gov->form;
            $logfixnew .= "[";
            $logfixnew .= $gov->tag;
            $logfixnew .= "] ";
            $logfixnew .= $dep->form;
            $logfixnew .= "[";
            $logfixnew .= $dep->tag;
            $logfixnew .= "] ";
        }
        else {
            $logfixnew = $dep->form;
            $logfixnew .= "[";
            $logfixnew .= $dep->tag;
            $logfixnew .= "] ";
            $logfixnew .= $gov->form;
            $logfixnew .= "[";
            $logfixnew .= $gov->tag;
            $logfixnew .= "] ";
        }
    }
    else {
        $logfixnew = '(removal)';
    }

    #output
    if ( $logfixold ne $logfixnew ) {
        if ( $logfixbundle->get_zone( 'cs', 'FIXLOG' ) ) {
            my $sentence = $logfixbundle->get_or_create_zone( 'cs', 'FIXLOG' )->sentence . " {$logfixmsg: $logfixold -> $logfixnew}";
            $logfixbundle->get_zone( 'cs', 'FIXLOG' )->set_sentence($sentence);
        }
        else {
            my $sentence = "{$logfixmsg: $logfixold -> $logfixnew}";
            $logfixbundle->create_zone( 'cs', 'FIXLOG' )->set_sentence($sentence);
        }
    }
}

my %byt_forms = (
    # correct forms
    'VB-S---3P-AA---' => 'je',
    'VB-S---3P-NA---' => 'není',
    'VB-P---3P-AA---' => 'jsou',
    'VB-P---3P-NA---' => 'nejsou',
    'VB-S---3F-AA---' => 'bude',
    'VB-S---3F-NA---' => 'nebude',
    'VB-P---3F-AA---' => 'budou',
    'VB-P---3F-NA---' => 'nebudou',
    'VpYS---XR-AA---' => 'byl',
    'VpYS---XR-NA---' => 'nebyl',
    'VpQW---XR-AA---' => 'byla',
    'VpQW---XR-NA---' => 'nebyla',
    'VpNS---XR-AA---' => 'bylo',
    'VpNS---XR-NA---' => 'nebylo',
    'VpMP---XR-AA---' => 'byli',
    'VpMP---XR-NA---' => 'nebyli',
    'VpTP---XR-AA---' => 'byly',
    'VpTP---XR-NA---' => 'nebyly',
    # heuristics for incomplete or overcomplete tags
    # present
    'VB-----3P-AA---' => 'je',
    'VB-----3P-NA---' => 'není',
    'VB-X---3P-AA---' => 'je',
    'VB-X---3P-NA---' => 'není',
    # future
    'VB-----3F-AA---' => 'bude',
    'VB-----3F-NA---' => 'nebude',
    'VB-X---3F-AA---' => 'bude',
    'VB-X---3F-NA---' => 'nebude',
    # past
    'VpM----XR-AA---' => 'byl',
    'VpM----XR-NA---' => 'nebyl',
    'VpMX---XR-AA---' => 'byl',
    'VpMX---XR-NA---' => 'nebyl',
    'VpI----XR-AA---' => 'byl',
    'VpI----XR-NA---' => 'nebyl',
    'VpIX---XR-AA---' => 'byl',
    'VpIX---XR-NA---' => 'nebyl',
    'VpF----XR-AA---' => 'byla',
    'VpF----XR-NA---' => 'nebyla',
    'VpFX---XR-AA---' => 'byla',
    'VpFX---XR-NA---' => 'nebyla',
    
);

sub get_form {

    my ( $self, $lemma, $tag ) = @_;

    $lemma =~ s/[-_].+$//;    # ???

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

    my $form_info = $morphoLM->best_form_of_lemma( $lemma, $tag );
    my $form = undef;
    $form = $form_info->get_form() if $form_info;

    if ( !$form ) {
        ($form_info) = $generator->forms_of_lemma( $lemma, { tag_regex => "^$tag" } );
        $form = $form_info->get_form() if $form_info;
    }

    # the "1" variant can be safely ignored
    if ( !$form && $tag =~ /1$/ ) {
	$tag =~ s/1$/-/;
	return $self->get_form($lemma, $tag);
    }

# reasonable but does not bring any improvement:
# if the tag is corrupt, it is usually a good idea not to try to
# generate any form and to keep the current form unchanged
#    if ( !$form && $lemma eq 'být' && $byt_forms{$tag} ) {
#	return $byt_forms{$tag};
#    }

    if ( !$form ) {
        print STDERR "Can't find a word for lemma '$lemma' and tag '$tag'.\n";
    }

    return $form;
}

sub regenerate_node {
    my ( $self, $node, $new_tag ) = @_;

    $node->set_tag($new_tag);    #set even if !defined $new_form

    my $old_form = $node->form;
    my $new_form = $self->get_form( $node->lemma, $new_tag );
    return if !defined $new_form;
    $new_form = ucfirst $new_form if $old_form =~ /^(\p{isUpper})/;
    $new_form = uc $new_form      if $old_form =~ /^(\p{isUpper}*)$/;
    $node->set_form($new_form);

    return $new_form;
}

sub get_pair {
    my ( $self, $node ) = @_;

    # "old"
    my $parent = $node->get_parent;
    while ( $node->is_member && !$parent->is_root() && $parent->afun =~ /^(Coord|Apos)$/ ) {
        $parent = $parent->get_parent();
    }

    # "new"
    # my $parent = $node->get_eparents({first_only => 1, or_topological => 1, ignore_incorrect_tree_structure => 1});
    # or probably better:
    # my ($parent) = $node->get_eparents({or_topological => 1, ignore_incorrect_tree_structure => 1});
    
    return undef if $parent->is_root;

    my $d_tag = $node->tag;
    my $g_tag = $parent->tag;
    $d_tag =~ /^..(.)(.)(.)/;
    my %d_categories = ( tag => $d_tag, gen => $1, num => $2, case => $3 );
    $g_tag =~ /^..(.)(.)(.)/;
    my %g_categories = ( tag => $g_tag, gen => $1, num => $2, case => $3 );

    return ( $node, $parent, \%d_categories, \%g_categories );
}

# if the form is about to change, it might be reasonable
# to change the morphological number instead
# and keep the form intact
# Returns the best tag to be used
sub try_switch_num {
    my ($self, $old_form, $lemma, $tag) = @_;

    my $new_form = $self->get_form( $lemma, $tag );

    # form is about to change
    if ( !$new_form || lc($old_form) ne lc($new_form) ) {
	# try to switch the number
	my $switched_tag = $self->switch_num($tag);
	$new_form = $self->get_form( $lemma, $switched_tag );
	if ( $new_form && lc($old_form) eq lc($new_form) ) {
	    # form does not change if number is switched
	    return $switched_tag;
	} else {
	    return $tag;
	}
    } else {
	# form doesn't change, no need to change the number
	return $tag;
    }
}

# returns the same tag with the opposite morphological number
sub switch_num {
    my ( $self, $tag ) = @_;
    
    if ( $tag =~ /^(...)S(.+)$/ ) {
	return $1.'P'.$2;
    } else {
	$tag =~ /^(...).(.+)$/;
	return $1.'S'.$2;
    }
}

# tries to guess whether the given node is a name
# TODO: the roughest possible implementation,
# use a proper named entity recognizer instead
sub isName {
    my ( $self, $node ) = @_;
    
    if ( $node->form && lc($node->form) eq $node->form ) {
	# with very high probability not a name
	return 0;
    } else {
	# can be a name, the start of a sentence, ...
	return 1;
    }
}


my %time_expr = (
    'Monday' => 1,
    'Tuesday' => 1,
    'Wednesday' => 1,
    'Thursday' => 1,
    'Friday' => 1,
    'Saturday' => 1,
    'Sunday' => 1,
    'January' => 1,
    'February' => 1,
    'March' => 1,
    'April' => 1,
    'May' => 1,
    'June' => 1,
    'July' => 1,
    'August' => 1,
    'September' => 1,
    'October' => 1,
    'November' => 1,
    'December' => 1,
    'second' => 1,
    'minute' => 1,
    'hour' => 1,
    'day' => 1,
    'week' => 1,
    'month' => 1,
    'year' => 1,
    'decade' => 1,
    'century' => 1,
    'beginning' => 1,
    'end' => 1,
);

sub isTimeExpr {
    my ( $self, $lemma ) = @_;
    
    if ($time_expr{$lemma}) {
	return 1;
    } else {
	return 0;
    }
}

sub isNumber {
    my ( $self, $node ) = @_;
    
    if (!defined $node) {
	return 0;
    }

    if ($node->tag =~ /^C/ || $node->form =~ /^[0-9%]/ ) {
 	return 1;
    } else {
	return 0;
    }
}

sub gn2pp {
    my ( $self, $gn ) = @_;
    $gn =~ s/[IF]P/TP/;
    $gn =~ s/[MI]S/YS/;
    $gn =~ s/(FS|NP)/QW/;
    return $gn;
}

sub remove_node {
    my ($self, $node, $en_hash, $rehang_under_en_eparent) = @_;

    #move children under parent
    my $parent = $node->get_parent;
    if ($rehang_under_en_eparent && $en_hash->{$node}) {
	my $en_parent = $en_hash->{$node}->get_eparents({first_only=>1, or_topological => 1});
        my ( $nodes ) = $en_parent->get_aligned_nodes();
        if ( $nodes->[0] && !$nodes->[0]->is_descendant_of($node) ) {
            $parent = $nodes->[0];
        }
    }
    foreach my $child ( $node->get_children ) {
	$child->set_parent($parent);
    }

    #remove alignment
    if ( $en_hash->{$node} ) {
	$en_hash->{$node}->set_attr( 'alignment', undef );
        # delete $en_hash->{$node};
    }

    #remove
    $node->remove;

    return;
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

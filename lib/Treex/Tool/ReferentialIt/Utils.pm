package Treex::Tool::ReferentialIt::Utils;

use Moose;

my $EXO_TYPE = 'exo';
my $REF_TYPE = 'ref';
my $PLEO_TYPE = 'pleo';

# TODO if appears to be neccessary, implement it as a NodeFilter
sub is_it {
    my ($node) = @_;

    if (blessed $node eq 'Treex::Core::Node::T') {
        my $it_num = grep {_is_it_anode($_)} $node->get_anodes;
        return $it_num;
    }
    elsif (blessed $node eq 'Treex::Core::Node::A') {
        return _is_it_anode($node);
    }
    return 0;
}

sub _is_it_anode {
    my ($anode) = @_;
    return ($anode->lemma eq 'it');
}

sub _is_ante_np {
    my (@antes) = @_;
    my @nouns = grep {defined $_->gram_sempos && ($_->gram_sempos =~ /^n/)} @antes;
    return (@nouns > 0);
}

sub get_it_type {
    my ($tnode_ref, $ref_np_only) = @_;

    my $lex_anode = $tnode_ref->get_lex_anode;
    if (defined $lex_anode && _is_it_anode($lex_anode)) {
        my @antes_ref = $tnode_ref->get_coref_nodes;
        if ((@antes_ref == 0) || ($ref_np_only && !_is_ante_np(@antes_ref))) {
            return $EXO_TYPE;
        }
        else {
            return $REF_TYPE;
        }
    }
    else {
        return $PLEO_TYPE;
    }
}

sub get_class_for_it_type {
    my ($it_type, $exo_as_pleo) = @_;
    if ($exo_as_pleo) {
        if ($it_type eq $REF_TYPE) {
            return 1;
        }
        else {
            return 0;
        }
    }
    else {
        if ($it_type eq $PLEO_TYPE) {
            return 0;
        }
        else {
            return 1;
        }
    }
}

1;
# TODO POD

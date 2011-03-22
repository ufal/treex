package Treex::Block::Write::ConllLike;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

use constant NOT_SET => "_"; # CoNLL-ST format: undefined value
use constant NO_NUMBER => -1; # CoNLL-ST format: undefined integer value
use constant FILL => "_"; # CoNLL-ST format: "fill predicate"
use constant TAG_FEATS => {"SubPOS" => 1, "Gen" => 2, "Num" => 3, "Cas" => 4, "PGe" => 5, "PNu" => 6, "Per" => 7, "Ten" => 8,
                   "Gra" => 9, "Neg" => 10, "Voi" => 11, "Var" => 14}; # tag positions and their meanings
use constant TAG_NOT_SET => "-"; # tagset: undefined value

has to => (
    isa => 'Str',
    is => 'ro',
    default => '-',
    documentation => 'the destination filename (standard output if nothing given)',
);

has _file_handle => (
    isa => 'FileHandle',
    is => 'rw',
    lazy_build => 1,
    builder => '_build_file_handle',
    documentation => 'the open output file handle',
);

sub _build_file_handle {
    
    my ($this) = @_;

    if ($this->to ne "-"){
        open(my $fh, '>:utf8', $this->to) or die("Could not open " . $this->to . " for output: $!");
        return $fh;
    }
    else {
        return \*STDOUT;
    }
}

sub DEMOLISH {
    my ($this) = @_;
    if ($this->to){
        close($this->_file_handle);
    }
}

# MAIN
sub process_ttree {

    my ($this, $t_root) = @_;
    my @data;
    
    # Get all needed informations for each node
    my @nodes = $t_root->get_descendants({ordered=>1}); 
    foreach my $node (@nodes){
        push(@data, get_node_info($node));
    }

    # sort, according to deepord
    @data = sort ord_sort @data;

    # print the results
    foreach my $line (@data){
        $this->_print_st($line);
    }
    print { $this->_file_handle } ("\n");
    return 1;
}

# Retrieves all the information needed for the conversion of each node and
# stores it as a hash.
sub get_node_info {

    my ($t_node) = @_;
    my $a_node = $t_node->get_lex_anode();
    my %info;

    $info{"ord"} = $t_node->ord;
    $info{"head"} = $t_node->get_parent() ? $t_node->get_parent()->ord : 0;
    $info{"functor"} = $t_node->functor ? $t_node->functor : NOT_SET;
    $info{"lemma"} = $t_node->t_lemma;

    if ($a_node){ # there is a corresponding node on the a-layer        
        $info{"tag"} = $a_node->tag;
        $info{"form"} = $a_node->form;
        $info{"afun"} = $a_node->afun;
    }
    else { # generated node
        $info{"tag"} = NOT_SET;
        $info{"afun"} = NOT_SET;
        $info{"form"} = $info{"lemma"};
    }

    # initialize aux-info
    $info{"aux_forms"} = "";
    $info{"aux_lemmas"} = "";
    $info{"aux_pos"} = "";
    $info{"aux_subpos"} = "";
    $info{"aux_afuns"} = "";

    # get all aux-info nodes
    my @aux_anodes = $t_node->get_aux_anodes();
    @aux_anodes = sort ord_sort @aux_anodes;

    # fill in the aux-info
    for my $aux_anode (@aux_anodes){
        $info{"aux_forms"} .= "|" . $aux_anode->form;
        $info{"aux_lemmas"} .= "|" . lemma_proper($aux_anode->lemma);
        $info{"aux_pos"} .= "|" . substr($aux_anode->tag, 0, 1);
        $info{"aux_subpos"} .= "|" . substr($aux_anode->tag, 1, 1);
        $info{"aux_afuns"} .= "|" . $aux_anode->afun;
    }

    $info{"aux_forms"} = $info{"aux_forms"} eq "" ? NOT_SET : substr($info{"aux_forms"}, 1);
    $info{"aux_lemmas"} = $info{"aux_lemmas"} eq "" ? NOT_SET : substr($info{"aux_lemmas"}, 1);
    $info{"aux_pos"} = $info{"aux_pos"} eq "" ? NOT_SET : substr($info{"aux_pos"}, 1);
    $info{"aux_subpos"} = $info{"aux_subpos"} eq "" ? NOT_SET : substr($info{"aux_subpos"}, 1);
    $info{"aux_afuns"} = $info{"aux_afuns"} eq "" ? NOT_SET : substr($info{"aux_afuns"}, 1);

    return \%info;
}


# Compares its arguments (hash references) according to the "ord" field.
sub ord_sort {
    return $a->{"ord"} <=> $b->{"ord"};
}


# Prints a data line in the pseudo-CoNLL-ST format:
#     ID, FORM, LEMMA, (nothing), PoS, (nothing), PoS Features, (nothing),
#     HEAD, (nothing), FUNCTOR, (nothing), Y, (nothing),
#     AFUN, AUX-FORMS, AUX-LEMMAS, AUX-POS, AUX-SUBPOS, AUX-AFUNS
sub _print_st {
    my ($this, $line) = @_;
    my ($pos, $pfeat) = analyze_tag($line->{"tag"});

    print { $this->_file_handle } (join("\t", ($line->{"ord"}, $line->{"form"}, 
        $line->{"lemma"}, NOT_SET, $pos, NOT_SET, $pfeat, NOT_SET,
        $line->{"head"}, NO_NUMBER, $line->{"functor"}, NOT_SET, FILL, NOT_SET,
        $line->{"afun"}, $line->{"aux_forms"}, $line->{"aux_lemmas"}, $line->{"aux_pos"}, $line->{"aux_subpos"}, $line->{"aux_afuns"})));
    print { $this->_file_handle } ("\n");
}


# Returns the PoS and PoS-Feat values, given a tag, or double "_", given a "_".
sub analyze_tag {
    
    my ($tag) = @_;

    if ($tag eq NOT_SET){
        return (NOT_SET, NOT_SET);
    }
    my $pos = substr($tag, 0, 1);
    my $pfeat = "";

    foreach my $feat (keys %{TAG_FEATS()}){
        my $pos = TAG_FEATS->{$feat};
        my $val = substr($tag, $pos, 1);

        if ($val ne TAG_NOT_SET){
            $pfeat .= $pfeat eq "" ? "" : "|";
            $pfeat .= $feat . "=" . $val;
        }
    }
    return ($pos, $pfeat);
}

# Given a PDT-style morphological lemma, returns just the "lemma proper" part without comments, links, etc.
sub lemma_proper {
    my ($lemma) = @_;

    $lemma =~ s/(_;|_:|_,|_\^|`).*$//;
    return $lemma;
}


1;

=over

=item Treex::Block::Write::CoNLL-Like

Prints out all t-trees in a text format similar to CoNLL (with no APREDs and some different values
relating to auxiliary a-nodes instead).

B<TODO:> Parametrize, so that the true CoNLL output as well as this extended version is possible;
    enable for English, too (now strictly depends on Czech morphological tags)

=back

=cut

# Copyright 2011 Ondrej Dusek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

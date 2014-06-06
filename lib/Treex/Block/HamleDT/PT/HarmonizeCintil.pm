package Treex::Block::HamleDT::PT::HarmonizeCintil;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has '+iset_driver' => (default=>'pt::cintil');

my %CHANGE_FORM = (
    '.*/' => '.',
    ',*/' => ',',
    q{\*'} => q{'},
);

my %CINTIL_DEPREL_TO_AFUN = (
    ROOT  => 'Pred',
    SJ    => 'Sb',   #  Subject 
    SJac  => 'Sb',   #  Subject  of  an  anticausative 
    SJcp  => 'Sb',   #  Subject  of  complex  predicate 
    DO    => 'Obj',  # Direct  Object 
    IO    => 'AuxP', # Indirect  Object 
    OBL   => 'AuxP', # Oblique  Object  
    M     => 'Atr',  # Modifier 
    PRD   => 'Pnom', # Predicate 
    SP    => 'AuxA', #  Specifier 
    N     => 'Atr',  # Name  in  multi‐word  proper  names
    CARD  => 'Atr',  # Cardinal  in  multi‐word  cardinals 
    PUNCT => 'AuxX', # Punctuation
    DEP   => 'AuxZ', #  Generic  dependency (mostly commas)
# C     => 'AuxC', #  Complement 
#COORD Coordination 
#CONJ   Conjunction 
);

sub process_zone {
    my ($self, $zone) = @_;

    # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);

    my $root  = $zone->get_atree();
    my @nodes = $root->get_descendants();

    foreach my $node (@nodes) {

        # Convert CoNLL POS tags and features to Interset and PDT if possible.
        $self->convert_tag($node);

        # Save interset features to the "tag" attribute,
        # so we can see them in TrEd
        #$node->set_tag($node->get_iset_conll_feat());
        $node->set_tag(join ' ', $node->get_iset_values());

        # CINTIL (parsed output) uses ".*/" instead of ".", let's fix it.
        $self->normalize_form($node);

        # Conversion from dependency relation tags to afuns (analytical function tags)
        my $afun = $self->guess_afun($node);
        $node->set_afun($afun || 'NR');
    }

    $self->attach_final_punctuation_to_root($root);

    $self->restructure_coordination($root);

    return;
}

sub get_input_tag_for_interset {
    my ($self, $node) = @_;
    return $node->conll_cpos();
}

sub normalize_form {
    my ($self, $node) = @_;
    my $real_form = $CHANGE_FORM{$node->form};
    if (defined $real_form) {
        $node->set_form($real_form);
    }
    return;
}

sub guess_afun {
    my ($self, $node) = @_;
    my $deprel   = $node->conll_deprel();
    my $pos      = $node->get_iset('pos');
#     my $parent   = $node->parent();
#     my $subpos   = $node->get_iset('subpos');
#     my $ppos     = $parent ? $parent->get_iset('pos') : '';

    if ($deprel eq 'CONJ'){
        $node->wild->{coordinator} = 1;
        return 'AuxY';
    }

    if ($deprel eq 'COORD'){
        $node->wild->{conjunct} = 1;
        return 'CoordArg';
    }
    
    if ($deprel eq 'C') {
        return 'Adv' if $pos eq 'noun';
        return 'AuxV' if $pos eq 'verb';
        return 'NR';
    }

    return 'AuxP' if $pos eq 'prep';

    return $CINTIL_DEPREL_TO_AFUN{$node->conll_deprel};
}

sub detect_coordination {
    my ($self, $node, $coordination, $debug) = @_;
    $coordination->detect_moscow($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return non-head conjuncts, private modifiers of the head conjunct and all shared modifiers for the Stanford family of styles.
    # (Do not return delimiters, i.e. do not return all original children of the node. One of the delimiters will become the new head and then recursion would fall into an endless loop.)
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = grep {$_ != $node} ($coordination->get_conjuncts());
    push(@recurse, $coordination->get_shared_modifiers());
    push(@recurse, $coordination->get_private_modifiers($node));
    return @recurse;
}


1;

=head1 NAME 

Treex::Block::HamleDT::PT::HarmonizeCintil

=head1 DESCRIPTION

Convert Portuguese treebank CINTIL to HamleDT style.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


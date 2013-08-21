package Treex::Tool::ReferentialIt::Features;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::NADA;
use Treex::Block::Eval::AddPersPronIt;

has 'feature_names' => (
    is          => 'ro',
    required    => 1,
    isa         => 'ArrayRef[Str]',
    lazy        => 1,
    builder     => '_build_feature_names',
);

has 'all_features' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Bool',
    default     => 1,
);

has '_nada_resolver' => (
    is => 'ro',
    isa => 'Treex::Tool::Coreference::NADA',
    required => 1,
    builder => '_build_nada_resolver',
);

has '_nada_probs' => (
    is => 'rw',
    isa => 'HashRef[Num]',
);

has '_en2cs_links' => (
    is => 'rw',
    isa => 'HashRef[Treex::Core::Node]',
);

sub _build_feature_names {
    my ($self) = @_;

    my @feat = qw/
        nada_prob_quant
        has_v_to_inf
        is_cog_verb
        is_be_adj_err
        is_cog_ed_verb_err
        rules_not_disj
    /;
    return \@feat;
}

sub _build_nada_resolver {
    my ($self) = @_;
    return Treex::Tool::Coreference::NADA->new();
}


sub create_instance {
    my ($self, $tnode, $en2cs_node) = @_;

    my $instance = {};

    my $alex = $tnode->get_lex_anode();

    my $verb;
    if ( ($tnode->gram_sempos || "") eq "v" ) {
        $verb = $tnode;
    }
    else {
        ($verb) = grep { ($_->gram_sempos || "") eq "v" } $tnode->get_eparents( { or_topological => 1} );
    }
    
    $instance->{has_v_to_inf} = (defined $verb) && Treex::Block::Eval::AddPersPronIt::has_v_to_inf($verb);
    $instance->{is_be_adj} = (defined $verb) && Treex::Block::Eval::AddPersPronIt::is_be_adj($verb);
    $instance->{is_cog_verb} = (defined $verb) && Treex::Block::Eval::AddPersPronIt::is_cog_verb($verb);
    $instance->{is_be_adj_err} = (defined $verb) && Treex::Block::Eval::AddPersPronIt::is_be_adj_err($verb);
    $instance->{is_cog_ed_verb_err} = (defined $verb) && Treex::Block::Eval::AddPersPronIt::is_cog_ed_verb_err($verb);
    if (defined $self->_en2cs_links) {
        $instance->{has_cs_to} = (defined $verb) && Treex::Block::Eval::AddPersPronIt::has_cs_to($verb, $self->_en2cs_links->{$tnode});
    }

    my ($it) = grep { $_->lemma eq "it" } $tnode->get_anodes;
    $instance->{en_has_ACT} = (defined $verb) && Treex::Block::Eval::AddPersPronIt::en_has_ACT($verb, $tnode, $it);
    $instance->{en_has_PAT} = (defined $verb) && Treex::Block::Eval::AddPersPronIt::en_has_PAT($verb, $tnode, $it);
    $instance->{make_it_to} = (defined $verb) && Treex::Block::Eval::AddPersPronIt::make_it_to($verb, $tnode);

    # TODO watch out! this is an error-prone implementation
    $instance->{rules_not_disj} =
        !(any {$instance->{$_}} qw/has_v_to_inf is_be_adj_err is_cog_verb is_cog_ed_verb_err/) ? 1 : 0;

    $instance->{nada_prob} = $self->_nada_probs->{$alex->id} || "__UNDEF__";
    
    $instance->{nada_prob_quant} = _quantize( $instance->{nada_prob}, 0.04 );

    if (!$self->all_features) {
        $instance = $self->filter_feats($instance);
    }

    return $instance;
}

sub filter_feats {
    my ($self, $instance) = @_;

    my $feat_names = $self->feature_names;

    my $new_instance = {};
    foreach my $feat_name (@$feat_names) {
        $new_instance->{$feat_name} = $instance->{$feat_name};
    }
    return $new_instance;
}

# TODO all quantizations should be handled at one place
sub _quantize {
    my ($value, $buck_size) = @_;

    return $value if ($value eq "__UNDEF__");
    
    # this strange thing with sprintf is a simulation of round() in Perl
    return $buck_size * (sprintf "%.0f", $value / $buck_size);
}

sub init_zone_features {
    my ($self, $zone) = @_;
    my $atree = $zone->get_atree;
    
    my $nada_probs = $self->_process_sentence_with_NADA( $atree );
    $self->_set_nada_probs( $nada_probs );
        
    ################# USED ONLY IF PARALEL DATA IS AVAILABLE ##########
    if ($zone->get_bundle->has_tree('cs','t','src')) {
        my $cs_src_tree = $zone->get_bundle->get_tree('cs','t','src');
        my %en2cs_node = Treex::Block::Eval::AddPersPronIt::get_en2cs_links($cs_src_tree);
        $self->_set_en2cs_links( \%en2cs_node );
    }
}

sub _process_sentence_with_NADA {
    my ($self, $atree) = @_;
    my @ids = map {$_->id} $atree->get_descendants({ordered => 1});
    my @words = map {$_->form} $atree->get_descendants({ordered => 1});
    
    my $result = $self->_nada_resolver->process_sentence(@words);
    my %it_ref_probs = map {$ids[$_] => $result->{$_}} keys %$result;
    
    return \%it_ref_probs;
}


1;
#TODO adjust POD
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::ReferentialIt::Features

=head1 DESCRIPTION

# TODO

=head1 PARAMETERS

=over

=item feature_names

Names of features that should be used for training/resolution. This list is, 
however, not obeyed inside this class. Method C<create_instance> returns all 
features that are extracted here, providing no filtering. It is a job of the 
calling method to decide whether to check the returned instances if they comply 
with the required list of features and possibly filter them.

=head1 METHODS

=over

# TODO

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

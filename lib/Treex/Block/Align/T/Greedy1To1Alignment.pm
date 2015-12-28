package Treex::Block::Align::T::Greedy1To1Alignment;
use Moose;
use TranslationDict::EN2CS;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has 'to_language' => ( isa => 'Treex::Type::LangCode', is => 'ro', lazy_build => 1 );
has 'to_selector' => ( isa => 'Str',      is => 'ro', default => '' );
has 'del_prev_align' => ( isa => 'Bool', is => 'ro', default => 1, required => 1 );
has 'using_walign' => ( isa => 'Bool', is => 'rw', default => 0 );
has 'feature_weight' => ( isa => 'HashRef', is => 'rw', lazy_build => 1 );
has 'type_name' => ( isa => 'Str', is => 'rw', default => 'greedy');
has 'threshold' => ( isa => 'Num', is => 'rw' );
has 'dict' => ( isa => 'Ref', is => 'rw', default => sub { TranslationDict::EN2CS->new });

sub _build_to_language {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->to_language && $self->selector eq $self->to_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
#    $self->dict = TranslationDict::EN2CS->new;
}

sub _build_feature_weight {
    my ($self) = @_;
    my $model;
    if ( $self->using_walign ) {
        ($model) = $self->require_files_from_share("data/models/weights_for_t_aligner/weights_using_walign.tsv");
    }
    else {
        ($model) = $self->require_files_from_share("data/models/weights_for_t_aligner/weights_not_using_walign.tsv");
    }
    my %feature_weight;
    open( MODEL, "<:utf8", $model ) or die;
    while (<MODEL>) {
        next if ( $_ =~ /^[^A-Za-z0-9]/ );
        my ($feature, $value) = split( /\s/, $_ );
        if ( $feature eq 'threshold' && !defined $self->threshold) {
            $self->set_threshold($value);
        }
        else {
            $feature_weight{$feature} = $value;
        }
    }
    close MODEL;
    return \%feature_weight;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $czech_atree = $bundle->get_tree($self->language, 'a', $self->selector);
    my $czech_ttree = $bundle->get_tree($self->language, 't', $self->selector);
    my $english_atree = $bundle->get_tree($self->to_language, 'a', $self->to_selector);
    my $english_ttree = $bundle->get_tree($self->to_language, 't', $self->to_selector);

    # GIZA++ alignment
    my %aligned_by_giza = ();
    if ($self->using_walign) {
        foreach my $cs_anode ( $czech_atree->get_children ) {
            my ( $nodes, $types ) = $cs_anode->get_directed_aligned_nodes();
            foreach my $i ( 0 .. $#$nodes ) {
                $aligned_by_giza{$cs_anode}{$$nodes[$i]} = $$types[$i];
            }
        }
    }

    # count of nodes (global)
    my $en_max_deepord = $english_ttree->get_descendants();
    my $cs_max_deepord = $czech_ttree->get_descendants();

    my %alignment_weight;
    my %aligned_pair;

    # load pairs from dictionary
    my %pair_in_dictionary;
    foreach my $en_tnode ( $english_ttree->get_descendants ) {
        my $en_lex_anode = $en_tnode->get_lex_anode;
        if ($en_lex_anode) {
            my $en_form = $en_lex_anode->get_attr('m/form');
            my $en_tag  = $en_lex_anode->get_attr('m/tag');
            foreach my $cs_tlemma_rf ( grep { $_->{source} =~ /(dict|deriv)/ } $self->dict->get_translations_plus_derivations( $en_tnode->t_lemma, $en_lex_anode->form, $en_lex_anode->tag ) ) {
                $pair_in_dictionary{$en_tnode->t_lemma}{ $cs_tlemma_rf->{cs_tlemma} } = $cs_tlemma_rf->{cs_given_en};
                $pair_in_dictionary{$en_tnode->t_lemma}{ lc( $cs_tlemma_rf->{cs_tlemma} ) } = $cs_tlemma_rf->{cs_given_en};
            }
        }
    }

    # delete previously made links
    if ($self->del_prev_align) {
        foreach my $tnode ( $czech_ttree->get_descendants ) {
            $tnode->set_attr( 'alignment', [] );
        }
    }

    # creating arrays of nodes
    my @en_tnodes = $english_ttree->get_descendants;
    my @cs_tnodes = $czech_ttree->get_descendants;

    # assigning score
    foreach my $en_tnode (@en_tnodes) {
        foreach my $cs_tnode (@cs_tnodes) {

            # compute alignment weight
            my %feature_value = ();
  
            # get T-lemmas
            my $en_tlemma = $en_tnode->t_lemma || '<no>';
            my $cs_tlemma = $cs_tnode->t_lemma || '<no>';
  
            # get Semantic part of speech
            my $en_sempos = $en_tnode->formeme || '<no>';
            my $cs_sempos = $cs_tnode->formeme || '<no>';
            $en_sempos =~ s/^([^:]*):.*$/$1/;
            $cs_sempos =~ s/^([^:]*):.*$/$1/;
  
            # get lexical A-nodes
            my $en_anode = $en_tnode->get_lex_anode;
            my $cs_anode = $cs_tnode->get_lex_anode;

            # get auxiliary A-nodes
            my @en_aux_anodes = $en_tnode->get_aux_anodes;
            my @cs_aux_anodes = $cs_tnode->get_aux_anodes;
  
            # --------------------------
            # FEATURES OF THIS TWO NODES
            # --------------------------
  
            # pair of tlemmas found in the dictionary
            if ( $pair_in_dictionary{$en_tlemma}{$cs_tlemma} ) {
                $feature_value{'r_tlemmas_in_dict'} = 1;
            }
  
            # translation probability p(cs_tlemma|en_t_lemma)
            if ( $pair_in_dictionary{$en_tlemma}{$cs_tlemma} ) {
                $feature_value{'r_probability_cs_given_en'} = $pair_in_dictionary{$en_tlemma}{$cs_tlemma};
            }
  
            # identical t_lemmas
            if (lc($en_tlemma) eq lc($cs_tlemma) or lc($en_tlemma) eq lc($cs_tlemma).".") {
                $feature_value{'r_identical_tlemmas'} = 1;
            }
  
            # equal number prefix of t_lemmas
            if ( $en_tlemma =~ /^(\d+)\D/ and $cs_tlemma =~ /^$1/ ) {
                $feature_value{'r_same_number_prefix'} = 1;
            }
  
            if ( substr( $en_tlemma, 0, 3 ) eq substr( $cs_tlemma, 0, 3 ) ) {
                $feature_value{'r_3letter_match'} = 1;
            }
  
            if ( substr( $en_tlemma, 0, 4 ) eq substr( $cs_tlemma, 0, 4 ) ) {
                $feature_value{'r_4letter_match'} = 1;
            }
  
            if (substr($en_tlemma, 0, 5) eq substr($cs_tlemma, 0, 5)) {
                $feature_value{'r_5letter_match'} = 1;
            }
  
            #   if ($en_anode && $cs_anode) {
            #       $feature_value{'c_shortened_tags§'.substr($en_anode->get_attr('m/tag'), 0, 2).'-'.substr($cs_anode->get_attr('m/tag'), 0, 2)} = 1;
            #   }
  
            if ( length($en_tlemma) >= 3 && length($cs_tlemma) >= 3 && ( substr( $en_tlemma, length($en_tlemma) - 3, 3 ) eq substr( $cs_tlemma, length($cs_tlemma) - 3, 3 ) ) ) {
                $feature_value{'r_last3letter_match'} = 1;
            }
  
            # aligned by GIZA++
            if ( $self->using_walign && $en_anode && $cs_anode ) {
                if ( $aligned_by_giza{$cs_anode}{$en_anode} ) {
                    if ( $aligned_by_giza{$cs_anode}{$en_anode} =~ /int/ ) {
                        $feature_value{'r_aligned_by_giza_int'} = 1;
                    }
                    if ( $aligned_by_giza{$cs_anode}{$en_anode} =~ /gdf/ ) {
                        $feature_value{'r_aligned_by_giza_gdf'} = 1;
                    }
                }
            }
  
            # one t-lemma is suffix of the other
            if ( $en_tlemma && $cs_tlemma ) {
                my $en_length = length($en_tlemma);
                my $cs_length = length($cs_tlemma);
                if ( ( $en_length > $cs_length ) && ( substr( $en_tlemma, $en_length - $cs_length, $cs_length ) eq $cs_tlemma ) ) {
                    $feature_value{'r_en_suffix'} = 1;
                }
                elsif ( ( $cs_length > $en_length ) && ( substr( $cs_tlemma, $cs_length - $en_length, $en_length ) eq $en_tlemma ) ) {
                    $feature_value{'r_cs_suffix'} = 1;
                }
            }
  
            # both nodes are coordination or aposition
            if ( $en_tnode->nodetype eq "coap" and $cs_tnode->nodetype eq "coap" ) {
                $feature_value{'r_both_coap'} = 1;
            }
  
            # adding weighted difference in relative position within the sentence
            my $relative_difference = abs($cs_tnode->ord / $cs_max_deepord - $en_tnode->ord / $en_max_deepord);
            $feature_value{'r_similarity_in_linear_position'} = 1 - $relative_difference;
  
            # FEATURES FOR PARENTS
            my $en_parent = $en_tnode->get_parent;
            my $cs_parent = $cs_tnode->get_parent;
            if ( $en_parent && $cs_parent && !$en_parent->is_root() && !$cs_parent->is_root() ) {
  
                # parent aligned by GIZA++
                my $en_parent_anode = $en_parent->get_lex_anode;
                my $cs_parent_anode = $cs_parent->get_lex_anode;
                if ( $en_parent_anode && $cs_parent_anode ) {
                    if ( $aligned_by_giza{$cs_parent_anode}{$en_parent_anode} ) {
                        if ( $aligned_by_giza{$cs_parent_anode}{$en_parent_anode} =~ /int/ ) {
                            $feature_value{'r_parents_aligned_by_giza_int'} = 1;
                        }
                        #           if ($aligned_by_giza{$cs_parent_mnode_id}{$en_parent_mnode_id} =~ /gdf/) {
                        #               $feature_value{'r_parents_aligned_by_giza_gdf'} = 1;
                        #           }
                    }
                }
  
                # parent tlemmas in the translation dictionary
                if ($pair_in_dictionary{$en_parent->t_lemma}{$cs_parent->t_lemma}) {
                    $feature_value{'r_parent_tlemmas_in_dict'} = 1;
                }
  
                # parent_translation_probability
                my $ptp = $pair_in_dictionary{ $en_parent->t_lemma }{ $cs_parent->t_lemma };
                $feature_value{'r_parent_translation_probability'} = $ptp if $ptp;
  
                # parent similarity in linear position
                $relative_difference = abs ($cs_parent->ord / $cs_max_deepord
                                     - $en_parent->ord / $en_max_deepord);
                $feature_value{'r_parent_similarity_in_linear_position'} = 1 - $relative_difference;
            }


            # compute weight of this connection
            my $weight = 0;
            foreach my $feature ( keys %feature_value ) {
                $weight += $feature_value{$feature} * ($self->feature_weight->{$feature} || 0);
            }
  
            $alignment_weight{$en_tnode}{$cs_tnode} = $weight;
        }
    }

    # 1:1 alignment
    my %aligned;
    my $node_count = @en_tnodes > @cs_tnodes ? scalar @en_tnodes : scalar @cs_tnodes;
    while ($node_count) {
        my $max_en_tnode;
        my $max_cs_tnode;
        my $max_weight = 0;
        foreach my $en_tnode (@en_tnodes) {
            next if defined $aligned{$en_tnode};
            foreach my $cs_tnode (@cs_tnodes) {
                next if defined $aligned{$cs_tnode};
                my $w = $alignment_weight{$en_tnode}{$cs_tnode};
                if ( $w > $max_weight ) {
                    $max_weight   = $w;
                    $max_en_tnode = $en_tnode;
                    $max_cs_tnode = $cs_tnode;
                }
            }
        }
        if ( $max_weight > $self->threshold ) {
            $aligned{$max_en_tnode} = 1;
            $aligned{$max_cs_tnode} = 1;
            $node_count--;

            # align
            $aligned_pair{$max_en_tnode}{$max_cs_tnode} = 1;
            $max_cs_tnode->add_aligned_node( $max_en_tnode, $self->type_name );
        }
        else {
            last;
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::T::Greedy1To1Alignment

=head1 DESCRIPTION

Alignment of tectogrammatical trees (see David Marecek's Master thesis http://ufal.mff.cuni.cz/~marecek/papers/2008_diplomka.pdf)

=head1 PARAMETERS

=item C<language>

The current language. This parameter is required.

=item C<to_language>

The target (reference) language for the alignment. Defaults to current C<language> setting. 
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.

=item C<to_selector>

The target (reference) selector for the alignment. Defaults to current C<selector> setting.
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

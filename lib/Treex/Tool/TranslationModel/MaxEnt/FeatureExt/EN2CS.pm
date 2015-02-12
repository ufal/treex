package Treex::Tool::TranslationModel::MaxEnt::FeatureExt::EN2CS;

use strict;
use warnings;
use Treex::Core::Common;

use Treex::Tool::TranslationModel::Features::Standard;

sub features_from_src_tnode {
    my ( $T_sd, $version ) = @_;    # (t)-node - (s)ource side, (d)ependent

    #log_warn "Using Treex::Tool::TranslationModel::MaxEnt::FeatureExt::EN2CS::features_from_src_tnode is deprecated. Use Treex::Tool::TranslationModel::Features::Standard::features_from_src_tnode instead.";

    return _features_from_src_tnode_czeng10($T_sd) if ( $version || '' ) =~ /^(1.0|1.1|1.2)$/;
    return _features_from_src_tnode_czeng09($T_sd);
}

sub _features_from_src_tnode_czeng10 {
    my ($T_sd) = shift;                                # (t)-node - (s)ource side, (d)ependent

    my $A_sd = $T_sd->get_lex_anode;

    if ( defined $A_sd ) {
        my $features = Treex::Tool::TranslationModel::Features::Standard::features_from_src_tnode($T_sd);

        return $features;
    }
    return;
}

sub _features_from_src_tnode_czeng09 {
    my ($T_sd) = shift;                                             # (t)-node - (s)ource side, (d)ependent
    my ($T_sg) = $T_sd->get_eparents( { or_topological => 1 } );    # governing

    my $A_sd = $T_sd->get_lex_anode;

    if ( defined $A_sd ) {
        my %features = (
            'tlemma_sd' => $T_sd->get_attr('t_lemma'),
            'tlemma_sg' => $T_sg->get_attr('t_lemma'),

            'formeme_sd' => $T_sd->get_attr('formeme'),
            'formeme_sg' => $T_sg->get_attr('formeme'),

            'tag_sd' => $A_sd->tag,

            'position' => ( $T_sd->precedes($T_sg) ? 'left' : 'right' ),

            'voice_sd' => $T_sd->get_attr('voice'),
            'voice_sg' => $T_sg->get_attr('voice'),

            'negation_sg' => $T_sg->get_attr('gram/negation'),
            'negation_sd' => $T_sd->get_attr('gram/negation'),

            'tense_sg' => $T_sg->get_attr('gram/tense'),
            'tense_sd' => $T_sd->get_attr('gram/tense'),

            'number_sg' => $T_sg->get_attr('gram/number'),
            'number_sd' => $T_sd->get_attr('gram/number'),

            'degree_sg' => $T_sg->get_attr('gram/degcmp'),
            'degree_sd' => $T_sd->get_attr('gram/degcmp'),

            'sempos_sg' => $T_sg->get_attr('gram/sempos'),
            'sempos_sd' => $T_sd->get_attr('gram/sempos'),

            'person_sg' => $T_sg->get_attr('gram/person'),
            'person_sd' => $T_sd->get_attr('gram/person'),

            'is_member' => $T_sd->get_attr('is_member'),
        );

        my $short_sempos_sg = $T_sg->get_attr('gram/sempos');
        if ( defined $short_sempos_sg ) {
            $short_sempos_sg =~ s/\..+//;
            $features{'short_sempos_sg'} = $short_sempos_sg;
        }

        if ( $A_sd->form =~ /^\p{IsUpper}/ ) {
            $features{'is_capitalized'} = 1;
        }

        my $A_sg = $T_sg->get_lex_anode;
        if ( defined $A_sg ) {
            $features{'tag_sg'} = $A_sg->tag;
            if ( $A_sg->form =~ /^\p{IsUpper}/ ) {
                $features{'parent_capitalized'} = 1;
            }
        }

        if ( $T_sd->get_children( { preceding_only => 1 } ) ) {
            $features{'has_left_child'} = 1;
        }

        if ( $T_sd->get_children( { following_only => 1 } ) ) {
            $features{'has_right_child'} = 1;
        }

        if ( my $prec_tnode = $T_sd->get_prev_node ) {
            $features{'prev_node_tlemma'} = $prec_tnode->get_attr('t_lemma');
        }
        else {
            $features{'prev_node_tlemma'} = '_SENT_START';
        }

        if ( my $next_tnode = $T_sd->get_next_node ) {
            $features{'next_node_tlemma'} = $next_tnode->get_attr('t_lemma');
        }
        else {
            $features{'next_node_tlemma'} = '_SENT_END';
        }

        foreach my $child ( $T_sd->get_echildren( { or_topological => 1 } ) ) {
            my $formeme = $child->get_attr('formeme');
            if ( defined $formeme ) {
                $features{"child_formeme_$formeme"} = 1;
            }
            $features{ "child_tlemma_" . $child->get_attr('t_lemma') } = 1;
        }

        foreach my $name ( keys %features ) {
            if ( not defined $features{$name} ) {
                delete $features{$name};
            }
        }

        AUX:
        foreach my $aux ( $T_sd->get_aux_anodes ) {
            my $form = lc( $aux->form );
            if ( $form eq "the" ) {
                $features{"determiner"} = "the";
                last AUX;
            }
            elsif ( $form =~ /^an?$/ ) {
                $features{"determiner"} = "a";
            }

        }

        if ( my $n_node = $T_sd->get_n_node() ) {
            $features{ne_type} = $n_node->get_attr('ne_type');
        }

        return \%features;
    }
    return undef;
}

1;

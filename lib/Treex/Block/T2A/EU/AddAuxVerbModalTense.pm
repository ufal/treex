package Treex::Block::T2A::EU::AddAuxVerbModalTense;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddAuxVerbModalTense';

override '_build_gram2form' => sub {

    return {
	'' => {
	    'ind' => {
		'sim' => {
		    ''        => '',
		    'decl'    => 'LEX-imp izan',
		    'poss'    => 'LEX- izan',
		    'deb'     => '',
		},
		'ant' => {
		    ''        => '',
		    'decl'    => 'LEX-perf izan',
		    'poss'    => 'LEX- ezan',
		    'deb'     => '',
		},
		'post' => {
		    ''     => '',
		    'decl' => 'LEX-pro izan',
		    'poss' => '',
		    'deb'  => '',
		},
	    },
	    'cdn' => {
		'sim' => {
		    ''        => '',
		    'decl'    => 'LEX-pro izan',
		    'poss'    => '',
		    'deb'     => '',
		},
		'ant' => {
		    ''        => '',
		    'decl'    => '',
		    'poss'    => '',
		    'deb'     => '',
		},
		'post' => {
		    ''     => '',
		    'decl' => '',
		    'poss' => '',
		    'deb'  => '',
		},
	    },
	    'imp' => {
		'sim' => {
		    ''        => '',
		    'decl'    => '',
		    'poss'    => '',
		    'deb'     => '',
		},
		'ant' => {
		    ''        => '',
		    'decl'    => '',
		    'poss'    => '',
		    'deb'     => '',
		},
		'post' => {
		    ''     => '',
		    'decl' => '',
		    'poss' => '',
		    'deb'  => '',
		},
	    },
	},
	'cpl' => {
	    'ind' => {
		'sim' => {
		    ''        => '',
		    'decl'    => '',
		    'poss'    => '',
		    'deb'     => '',
		},
		'ant' => {
		    ''        => '',
		    'decl'    => 'LEX-perf izan',
		    'poss'    => '',
		    'deb'     => '',
		},
		'post' => {
		    ''     => '',
		    'decl' => '',
		    'poss' => '',
		    'deb'  => '',
		},
	    },
	    'cdn' => {
		'sim' => {
		    ''        => '',
		    'decl'    => '',
		    'poss'    => '',
		    'deb'     => '',
		},
		'ant' => {
		    ''        => '',
		    'decl'    => '',
		    'poss'    => '',
		    'deb'     => '',
		},
		'post' => {
		    ''     => '',
		    'decl' => '',
		    'poss' => '',
		    'deb'  => '',
		},
	    },
	    'imp' => {
		'sim' => {
		    ''        => '',
		    'decl'    => '',
		    'poss'    => '',
		    'deb'     => '',
		},
		'ant' => {
		    ''        => '',
		    'decl'    => '',
		    'poss'    => '',
		    'deb'     => '',
		},
		'post' => {
		    ''     => '',
		    'decl' => '',
		    'poss' => '',
		    'deb'  => '',
		},
	    },
	},
    };
};

my @synthetic = ('egon');

override 'process_tnode' => sub {
    my ( $self, $tnode ) = @_;
    my ( $verbmod, $tense, $deontmod, $aspect ) = ( $tnode->gram_verbmod // '', $tnode->gram_tense // '', $tnode->gram_deontmod // '', $tnode->gram_aspect // '');

    # return if the node is not a verb
    return if ( !$verbmod );

    # find the auxiliary appropriate verbal expression for this combination of verbal modality, tense, and deontic modality
    # do nothing if we find nothing
    # TODO this should handle epistemic modality somehow. The expressions are in the array, but are ignored.
    return if ( !$self->gram2form->{$aspect} or !$self->gram2form->{$aspect}->{$verbmod} or !$self->gram2form->{$aspect}->{$verbmod}->{$tense} or !$self->gram2form->{$aspect}->{$verbmod}->{$tense}->{$deontmod});
    my $verbforms_str = $self->gram2form->{$aspect}->{$verbmod}->{$tense}->{$deontmod};
    return if ( !$verbforms_str );

    return if ( $deontmod eq 'decl' && grep {$tnode->t_lemma eq $_} @synthetic);

    my $transitive = $self->is_transitive($tnode);

    # find the original anode
    my $anode = $tnode->get_lex_anode() or return;
    my $lex_lemma = $anode->lemma;

    my @verbforms = split / /, $verbforms_str;
    my $last_verbform = pop @verbforms;

    $last_verbform='ukan' if ($transitive && $last_verbform eq "izan");
    $last_verbform='edin' if ($transitive && $last_verbform eq "ezan");

    # replace the current verb node by the first part of the auxiliary verbal expression
    $anode->set_lemma($last_verbform);
    $anode->set_afun('AuxV');
    $anode->iset->add("tense" => "pres") if ($tnode->gram_tense eq "post");


    my @anodes      = ();

    # add the rest (including the original verb) as "auxiliary" nodes
    foreach my $verbform ( reverse @verbforms ) {
	my ($lemma, $asp) = split(/-/, $verbform);

	next if ($lemma =~ /^LEX/ && ($lex_lemma eq 'izan' || $lex_lemma eq 'ukan'));

        my $new_node = $anode->create_child();
        $new_node->reset_morphcat();

	if ($tnode->gram_negation eq "neg1") {
	    $new_node->shift_after_node($anode);
	}
	else {
	    $new_node->shift_before_node($anode);
	}


        $tnode->add_aux_anodes($new_node);
        unshift @anodes, $new_node;

        # creating auxiliary part
        if ($lemma ne "LEX") {
	    $new_node->set_lemma($lemma);
            $new_node->set_morphcat_pos('!');
            $new_node->set_form($verbform);
            $new_node->set_afun('AuxV');
        }

        # creating a new node for the lexical verb
        else {
	    $new_node->set_lemma($lex_lemma);
            $new_node->set_morphcat_pos('V');
            $new_node->set_afun('Obj');
	    $new_node->iset->add('pos' => 'verb');
	    $new_node->iset->add('verbform' => 'part', 'aspect' => $asp ) if ($asp);

            # mark the lexical verb for future reference (if not already marked by AddAuxVerbCompoundPassive)
            if ( !grep { $_->wild->{lex_verb} } $tnode->get_aux_anodes() ) {
                $new_node->wild->{lex_verb} = 1;
            }
        }
    }

    push @anodes, $anode;

    $self->_postprocess( $verbforms_str, \@anodes );

    return;
};

sub is_transitive {
    my ($self, $tnode) = @_;

    return 1 if ( any { $_->formeme =~ /^n:erg/ } $tnode->get_children() );

    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::AddAuxVerbModalTense

=head1 DESCRIPTION

Add auxiliary expression for combined modality and tense.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

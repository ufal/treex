package Treex::Block::T2A::CS::GenerateCompoundVerbforms;

use Moose;
use Treex::Core::Common;
use Treex::Block::Write::Arff;

extends 'Treex::Tool::ML::MLProcessBlock';

has '+model_dir'     => ( default => 'data/models/generation/cs_verbforms/' );
has '+plan_template' => ( default => 'plan.template' );

has 'features_config' => ( isa => 'Str', is => 'ro', default => 'features.yml' );

has '+model_files' => ( builder => '_build_model_files', lazy_build => 1 );

has '+plan_vars' => (
    default => sub {
        return {
            'MODEL'   => 'model.dat',
            'FF-INFO' => 'ff.dat',
        };
        }
);

sub _build_model_files {
    my ($self) = @_;
    return [
        'ff.dat',
        'model.dat',
        $self->plan_template,
        $self->features_config,
    ];
}

has '+class_name' => ( default => 'verbform' );

# Conversion a-node -> t-node
has '_a2t' => ( isa => 'HashRef', is => 'rw' );

# Conversion table from deontmod grammateme values to modal verb lemmas
Readonly my %DEONTMOD_TO_MODAL_VERB => (
    'poss' => 'moci',
    'vol'  => 'chtít',
    'deb'  => 'muset',
    'hrt'  => 'mít',
    'fac'  => 'moci',     # translation of 'be able to'
    'perm' => 'moci',     # translation of 'might'
);

# Prepare a-node -> t-node map
override 'process_ttree' => sub {

    my ( $self, $troot ) = @_;

    $self->_set_a2t( {} );

    foreach my $tnode ( $troot->get_descendants() ) {
        foreach my $anode ( $tnode->get_anodes() ) {
            $self->_a2t->{$anode} = $tnode;
        }
    }
    super;
};

override '_write_input_data' => sub {

    my ( $self, $document, $file ) = @_;

    # print out data in ARFF format for the ML-Process program
    log_info( "Writing the ARFF data to " . $file );
    my $arff_writer = Treex::Block::Write::Arff->new(
        {
            to          => $file->filename,
            language    => $self->language,
            selector    => $self->selector,
            config_file => $self->model_dir . $self->features_config,
            layer       => 't',
            clobber     => 1
        }
    );

    $arff_writer->process_document($document);
    return;
};

override '_set_class_value' => sub {

    my ( $self, $tnode, $value ) = @_;

    return if ( $value eq '' );

    $tnode->wild->{verbform} = $value;

    my $anode = $tnode->get_lex_anode();
    return if ( !$anode );

    # create the new verbal subtree
    my $aparent = $anode->get_parent();
    my $top_anode = $self->_create_subtree( $anode, $value );
    $top_anode->set_parent($aparent);

    # copy some needed attributes from the old node into the new root node
    $top_anode->wild->{is_parenthesis} = $anode->wild->{is_parenthesis};
    $top_anode->set_is_member( $anode->is_member );

    # copy some attributes off the old node into the whole structure
    my @new_anodes = $top_anode->get_descendants( { add_self => 1 } );
    my ( $person, $number, $gender ) = (
        $anode->get_attr('morphcat/person'),
        $anode->get_attr('morphcat/number'),
        $anode->get_attr('morphcat/gender')
    );

    foreach my $node (@new_anodes) {

        foreach my $cat ( 'case', 'grade', 'possgender', 'possnumber', 'reserve1', 'reserve2' ) {
            $node->set_attr( 'morphcat/' . $cat, '.' );
        }

        $node->set_attr( 'morphcat/person', $person );
        $node->set_attr( 'morphcat/number', $number );
        $node->set_attr( 'morphcat/gender', $gender );
    }

    # find out the modal verb and fill in its lemma
    my $modal_anode = first { $_->lemma eq '_M' } @new_anodes;
    if ($modal_anode) {
        $modal_anode->set_lemma( $DEONTMOD_TO_MODAL_VERB{ $tnode->gram_deontmod } );
    }

    # find out the main verb and fill in its lemma
    my $new_lex_anode = first { $_->lemma eq '_L' } @new_anodes;
    $new_lex_anode->set_lemma( $anode->lemma );

    # rehang all the children of the original verb under the new structure
    foreach my $child ( $anode->get_children ) {
        my $lex_child = $self->_get_lex_anode($child);
        my $rehang_to_lex = $lex_child ? $lex_child->wild->{lex_verb_child} : 0;
        $child->set_parent( $rehang_to_lex ? $new_lex_anode : $top_anode );
    }

    # set the new structure as aux and lex anodes of the corresponding t-node
    $tnode->set_lex_anode($new_lex_anode);
    $tnode->add_aux_anodes( grep { $_ != $new_lex_anode } @new_anodes );

    # remove the old verbal node
    $anode->remove();
};

# For an a-node, return the corresponding LEXICAL a-node (via the a-node to t-node map)
sub _get_lex_anode {
    my ( $self, $anode ) = @_;
    
    my $tnode = $self->_a2t->{$anode};
    return undef if (!$tnode);
    return $tnode->get_lex_anode();
}

sub _create_subtree {

    my ( $self, $node, $topology, $par_right ) = @_;
    my $right = 0;    
    my $child;

    while ($topology) {

        # dive deeper (and create child at the right position)
        if ( $topology =~ m/^\(/ ) {

            $child = $node->create_child();
            if ($right) {
                $child->shift_after_node($node);
            }
            else {
                $child->shift_before_node($node);
            }
            $topology = $self->_create_subtree( $child, substr( $topology, 1 ), $right );
        }

        # return the topology still to be parsed
        elsif ( $topology =~ m/^\)/ ) {
            $topology = substr( $topology, 1 );
            return $topology;
        }

        # fill in the needed values
        else {
            my ( $morph, $lemma ) = $topology =~ m/([^ ]+) ([^\(\)]+)/;
            $topology =~ s/^[^ ]+ [^\(\)]+//;
            $right = 1;

            $node->set_lemma($lemma);

            if ( $lemma !~ m/^_/ ) {
                $node->set_afun('AuxV');
            }

            foreach my $cat ( 'pos', 'subpos', 'tense', 'negation', 'voice' ) {
                $node->set_attr( 'morphcat/' . $cat, substr( $morph, 0, 1 ) );
                $morph = substr( $morph, 1 );
            }
        }
    }

    # at the end of the whole sequence, return the root of the created substructure
    return ($child);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::GenerateCompoundVerbforms

=head1 DESCRIPTION

This block generates whole Czech compound verb form subtrees from the verbal t-node and its
grammatemes, according to a machine learning model using L<Treex::Tool::ML::MLProcess>.

Some values, such as modal verb and main verb lemmas, person, number and gender, are filled-in
directly from the t-node attributes.   

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

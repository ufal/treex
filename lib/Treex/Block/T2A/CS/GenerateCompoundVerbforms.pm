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
    my $child = $self->_create_subtree( $anode, $value );
    $child->set_parent($aparent);

    # copy some needed attributes from the old node into the new root node    
    $child->wild->{is_parenthesis} = $anode->wild->{is_parenthesis};

    # copy some attributes off the old node into the whole structure
    my @new_anodes = $child->get_descendants( { add_self => 1 } );
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

    # find out the main verb and fill in its lemma
    my ($new_anode) = grep { $_->lemma eq '_' } @new_anodes;
    $new_anode->set_lemma( $anode->lemma );

    # rehang all the children of the original verb under the new structure
    foreach my $child ( $anode->get_children ) {
        $child->set_parent($new_anode);
    }

    # set the new structure as aux and lex anodes of the corresponding t-node
    $tnode->set_lex_anode($new_anode);
    $tnode->add_aux_anodes( grep { $_ != $new_anode } @new_anodes );

    # remove the old verbal node
    $anode->remove();
};

sub _create_subtree {

    my ( $self, $node, $topology, $right ) = @_;
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
            my ( $morph, $lemma ) = $topology =~ m/([^ ]+) ([^ ]+)/;
            $topology =~ s/^[^ ]+ [^ ]+ //;
            $right = 1;

            $node->set_lemma($lemma);

            if ( $lemma ne '_' ) {
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


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Core::TredView::Vallex;

use Moose;
use Treex::Core::TredView::Common;
use Treex::Core::Log;

has '_treex_doc' => (
    is       => 'ro',
    isa      => 'Treex::Core::Document',
    weak_ref => 1,
    required => 1
);

sub _extension_missing {
    my ( $self, $ext ) = @_;

    my $name = '';
    $name = 'Prague English Treebank Annotation' if $ext eq 'pedt';
    $name = 'PDT-ValLex Editor' if $ext eq 'pdt_vallex';

    my $message = "This function requires additional extension that is missing.\n";
    $message .= "Please install extension '$name'.";
    TredMacro::ToplevelFrame->messageBox( -type => 'ok', -message => $message );
    return;
}

sub _find_vallex {
    my ( $self, $node ) = @_;

    my $ref = $node->attr('val_frame.rf');
    $ref =~ s/#.*//;

    my $file = $self->_treex_doc->metaData('references')->{$ref};
    $file = TredMacro::ResolvePath( TredMacro::FileName(), $file, 1 );
    return $file;
}

sub OpenValLexicon
{
    my $self = shift;
    my $node = Treex::Core::TredView::Common::cur_node();
    return unless $node->attr('val_frame.rf');

    if ( $node->language eq 'cs' ) {
        $self->_OpenValLexicon_Cs($node);
    }
    if ( $node->language eq 'en' ) {
        $self->_OpenValLexicon_En($node);
    }
    return;
}

sub ChooseValFrame
{
    my $self = shift;
    my $node = Treex::Core::TredView::Common::cur_node();
    return unless $node->attr('val_frame.rf');

    if ( $node->language eq 'cs' ) {
        $self->_OpenValFrameList_Cs($node);
    }
    if ( $node->language eq 'en' ) {
        $self->_OpenValFrameList_En($node);
    }
    return;
}

sub _assigned_frame_pos_of {
    my ( $self, $node ) = @_;
    return unless $node;
    if ( $node->{'val_frame.rf'} ne q() )
    {
        my $vallex_file = FindVallex('cz');
        my $V = ValLex::GUI::Init( { -vallex_file => $vallex_file } );
        if ($V)
        {
            for my $id ( AltV( $node->{'val_frame.rf'} ) )
            {
                my $frame = $V->by_id($id);
                if ($frame)
                {
                    return lc( $V->getPOS( $V->getWordForFrame($frame) ) );
                }
            }
        }
    }
    return;
}

sub _OpenValLexicon_Cs {
    my ( $self, $node ) = @_;

    if ( not defined &ValLex::GUI::OpenEditor ) {
        $self->_extension_missing('pdt_vallex');
        return;
    }

    local $ValLex::GUI::frameid_attr = "val_frame.rf";
    local $ValLex::GUI::lemma_attr   = "t_lemma";
    local $ValLex::GUI::framere_attr = undef;
    local $ValLex::GUI::sempos_attr  = "gram/sempos";
    my $vallex_file = $self->_find_vallex($node);
    return unless $vallex_file;

    ValLex::GUI::OpenEditor(
        {
            -vallex_file => $vallex_file,
            -lemma       => $node->attr('t_lemma'),
            -sempos      => $node->attr('gram/sempos') || $self->_assigned_frame_pos_of($node),
            -frameid     => $node->attr('val_frame.rf')
        }
    );
    TredMacro::ChangingFile(0);
    return;
}

sub _OpenValLexicon_En {
    my ( $self, $node ) = @_;

    if ( not defined &TrEd::EngValLex::GUI::OpenEditor ) {
        $self->_extension_missing('pedt');
        return;
    }

    local $TrEd::EngValLex::GUI::frameid_attr = "val_frame.rf";
    local $TrEd::EngValLex::GUI::lemma_attr   = "t_lemma";
    local $TrEd::EngValLex::GUI::framere_attr = undef;
    local $TrEd::EngValLex::GUI::sempos_attr  = "gram/sempos";
    $TrEd::EngValLex::Editor::reviewer_can_modify = 0;
    $TrEd::EngValLex::Editor::reviewer_can_delete = 0;

    # Following subroutines return 1 no matter what. We need to change this behaviour
    require TrEd::EngValLex::Data;
    *TrEd::EngValLex::Data::user_is_annotator = sub { return 0 };
    *TrEd::EngValLex::Data::user_is_reviewer  = sub { return 0 };

    my $a_node      = $self->_treex_doc->get_node_by_id( $node->attr('a/lex.rf') );
    my $vallex_file = $self->_find_vallex($node);
    return unless $vallex_file;

    my $opts = {
        -vallex_file => $vallex_file,
        -lemma       => $node->attr('t_lemma'),
        -sempos      => $node->attr('gram/sempos'),
        -frameid     => $node->attr('val_frame.rf')
    };
    $opts->{-pos} = $a_node->attr('tag') if $a_node->attr('tag');
    TrEd::EngValLex::GUI::OpenEditor($opts);
    TredMacro::ChangingFile(0);
    return;
}

sub _OpenValFrameList_Cs {
    my ( $self, $node ) = @_;

    if ( not defined &ValLex::GUI::ChooseFrame ) {
        $self->_extension_missing('pdt_vallex');
        return;
    }

    local $ValLex::GUI::frameid_attr = "val_frame.rf";
    local $ValLex::GUI::lemma_attr   = "t_lemma";
    local $ValLex::GUI::framere_attr = undef;
    local $ValLex::GUI::sempos_attr  = "gram/sempos";
    my $vallex_file = $self->_find_vallex($node);
    return unless $vallex_file;

    my $sempos = [ $node->attr('gram/sempos') || $self->_assigned_frame_pos_of($node) ];
    if ( !$sempos->[0] ) {
        $sempos = ['v'];
        ListQuery( 'Semantical POS', 'browse', [qw(v n)], $sempos ) or return;
    }

    ValLex::GUI::ChooseFrame(
        {
            -withdraw    => 1,
            -vallex_file => $vallex_file,
            -lemma       => $node->attr('t_lemma') || undef,
            -sempos      => $sempos->[0],
            -lemma_attr  => 't_lemma',
            -sempos_attr => 'gram/sempos',
            -frameid     => $node->attr('val_frame.rf'),
            -no_assign   => 1,
            -noadd       => 1
        }
    );
    TredMacro::ChangingFile(0);
    return;
}

sub _OpenValFrameList_En {
    my ( $self, $node ) = @_;

    if ( not defined &TrEd::EngValLex::GUI::ChooseFrame ) {
        $self->_extension_missing('pedt');
        return;
    }

    local $EngValLex::GUI::frameid_attr = "val_frame.rf";
    local $EngValLex::GUI::lemma_attr   = "t_lemma";
    local $EngValLex::GUI::framere_attr = undef;
    local $EngValLex::GUI::sempos_attr  = "gram/sempos";
    $TrEd::EngValLex::Editor::reviewer_can_modify = 0;
    $TrEd::EngValLex::Editor::reviewer_can_delete = 0;

    # Following subroutines return 1 no matter what. We need to change this behaviour
    require TrEd::EngValLex::Data;
    *TrEd::EngValLex::Data::user_is_annotator = sub { return 0 };
    *TrEd::EngValLex::Data::user_is_reviewer  = sub { return 0 };

    my $a_node      = $self->_treex_doc->get_node_by_id( $node->attr('a/lex.rf') );
    my $vallex_file = $self->_find_vallex($node);
    return unless $vallex_file;

    my $opts = {
        -withdraw    => 1,
        -vallex_file => $vallex_file,
        -lemma       => $node->{t_lemma} || undef,
        -sempos      => $node->attr('gram/sempos') || undef,
        -lemma_attr  => 't_lemma',
        -sempos_attr => 'gram/sempos',
        -frameid     => $node->attr('val_frame.rf'),
        -assignfunc  => sub { }
    };
    $opts->{-pos} = $a_node->attr('tag') if $a_node->attr('tag');
    TrEd::EngValLex::GUI::ChooseFrame($opts);
    TredMacro::ChangingFile(0);
    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Core::TredView::Vallex - Browsing valency lexicons

=head1 DESCRIPTION

This package provides browsers of valency lexicons

=head1 METHODS

=head2 Public methods

=over 4

=item OpenValLexicon

=item ChooseValFrame

=back

=head2 Private methods

=over 4

=item _OpenValLexicon_Cs

=item _ChooseValFrame_Cs

=item _OpenValLexicon_En

=item _ChooseValFrame_En

=item _extension_missing

=item _find_vallex

=item _assigned_frame_pos_of

=back

=head1 AUTHOR

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


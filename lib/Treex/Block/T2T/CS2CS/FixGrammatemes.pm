package Treex::Block::T2T::CS2CS::FixGrammatemes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

has 'magic' => ( is => 'ro', isa => 'Str', default => '' );

use Treex::Block::T2T::EN2CS::FixGrammatemesAfterTransfer;

my $tectoFixBlock;

sub process_start {
    my ($self) = @_;

    $tectoFixBlock = Treex::Block::T2T::EN2CS::FixGrammatemesAfterTransfer->new();

    return ;
}

sub fill_node_info {
    my ( $self, $node_info ) = @_;
    
    $self->fill_info_from_tree($node_info);
    
    # remember old grammatemes
    $node_info->{grammatemes_orig} =
        hashref2string ($node_info->{node}->get_attr('gram'));

    return;
}

sub hashref2string {
    my ($hashref) = @_;
    
    # TODO: handle undefs
    return join ' ', map { "$_:$hashref->{$_}" } sort keys %$hashref; 
}

sub decide_on_change {
    my ($self, $node_info) = @_;

    # try to fix grammatemes
    my $cs_t_node  = $node_info->{node}; 
    my $en_t_node  = $node_info->{ennode} or return;
    my $cs_formeme = $node_info->{formeme};
    my $en_formeme = $node_info->{enformeme};

    # Some English clause heads may become non-heads and vice versa
    $cs_t_node->set_is_clause_head( $cs_formeme =~ /n:pokud_jde_o.4|v.+(fin|rc)/ ? 1 : 0 );

    # fix the set of grammatemes if there are sempos changes
    $tectoFixBlock->_fix_valid_grammatemes( $cs_t_node, $en_t_node );

    # compensate number assymetries
    $tectoFixBlock->_fix_number( $cs_t_node, $en_t_node );

    $tectoFixBlock->_fix_gender( $cs_t_node, $en_t_node );

    $tectoFixBlock->_fix_negation( $cs_t_node, $en_t_node ) if ( !$tectoFixBlock->ignore_negation );

    $tectoFixBlock->_fix_degcmp( $cs_t_node, $en_t_node );

    # fix verbal grammatemes if verbal form has changed
    $tectoFixBlock->_fix_tense_verbmod( $cs_t_node, $en_t_node ) if ( $cs_formeme =~ /^v/ );
    


    # check whether anything changed
    $node_info->{grammatemes_new} =
        hashref2string ($node_info->{node}->get_attr('gram'));

    $node_info->{change} = (
        $node_info->{grammatemes_new} ne $node_info->{grammatemes_orig});

    return;
}


sub do_the_change {
    my ($self, $node_info) = @_;

    # change already done 

    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::FixGrammatemes -
An attempt to fix incorrect grammatemes,
using knowledge of English side.
(A Deepfix block.)

=head1 DESCRIPTION

Wrapper for Treex::Block::T2T::EN2CS::FixGrammatemesAfterTransfer

=head1 PARAMETERS

=over

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

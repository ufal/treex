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
    my ( $self, $node ) = @_;
    
    $self->fill_info_basic($node);
    $self->fill_info_aligned($node);
    
    return;
}

sub fix {
    my ($self, $node) = @_;

    # remember old grammatemes
    my $old_gram = ($node->get_attr('gram')) ? { %{$node->get_attr('gram')} } : undef;

    # try to fix grammatemes
    my $cs_t_node  = $node; 
    my $en_t_node  = $node->wild->{'deepfix_info'}->{ennode} or return;
    my $cs_formeme = $node->formeme;
    my $en_formeme = $node->wild->{'deepfix_info'}->{enformeme};

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
    my $new_gram = ($node->get_attr('gram')) ? { %{$node->get_attr('gram')} } : undef;

    my $old_gram_string = hashref2string($old_gram);
    my $new_gram_string = hashref2string($new_gram);
    if ($old_gram_string ne $new_gram_string) {
        log_info("gramatemes changed: $old_gram_string -> $new_gram_string");
        # TODO compare gramatemes and make changes where applicable
        # (use some TectoMT block to do this)
        # for...
    }

    return;
}

sub hashref2string {
    my ($hashref) = @_;
    
    if (defined $hashref) {
        # TODO: handle undefs
        return join ' ', map { "$_:$hashref->{$_}" } sort keys %$hashref;
    }
    else {
        return '';
    }
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

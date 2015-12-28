package Treex::Block::Project::Coreference;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has alignment_type => (isa=>'Str', is=>'ro', default=>'.*', documentation=>'Use only alignments whose type is matching this regex. Default is ".*".');
has alignment_direction => (
    is=>'ro',
    isa=>enum( [qw(src2trg trg2src)] ),
    default=>'trg2src',
    documentation=>'Default trg2src means alignment from <language,selector> to <source_language,source_selector> tree. src2trg means the opposite direction.',
);

sub process_tnode {
    my ( $self, $node ) = @_;
    my $src_node = $self->get_aligned($node, 0) or return;
    
    if ( my $coref_gram = $src_node->get_deref_attr('coref_gram.rf') ) {
        my @nodelist = map { $self->get_aligned($_, 1) } @$coref_gram;
        $node->set_deref_attr( 'coref_gram.rf', \@nodelist );
    }
    if ( my $coref_text = $src_node->get_deref_attr('coref_text.rf') ) {
        my @nodelist = map { $self->get_aligned($_, 1) } @$coref_text;
        $node->set_deref_attr( 'coref_text.rf', \@nodelist );
    }        
    
    return;
}

sub get_aligned {
    my ( $self, $node, $is_src) = @_;
    my @aligned;
    if ($is_src xor $self->alignment_direction eq 'trg2src'){
        @aligned = $node->get_aligned_nodes_of_type($self->alignment_type);
    } else {
        @aligned = grep {$_->is_directed_aligned_to($node, {rel_types => [$self->alignment_type]})}
                   $node->get_referencing_nodes('alignment');
    }
    return if !@aligned;
    return $aligned[0];
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Project::Coreference - copy coreference links via alignment

=head1 SYNOPSIS

 Project::Coreference language=cs alignment_direction=src2trg 
 
 # You can constrain types of alignment links to be used by specifying regex pattern.
 ... alignment_type=(manual|gdfa)
 
=head1 DESCRIPTION

copy coreference links via alignment

=head1 SEE ALSO

L<Treex::Block::Project::Tree>
L<Treex::Block::Project::Attributes>
L<Treex::Block::T2T::CopyTtree>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

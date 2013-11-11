package Treex::Block::Write::Alignments;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has layer               => ( isa => 'Treex::Type::Layer', is => 'ro', default=> 'a' );
has source_language     => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );
has source_selector     => ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );
has alignment_type      => ( isa => 'Str', is => 'ro', default => '.*', documentation => 'Use only alignments whose type is matching this regex. Default is ".*".' );
has alignment_direction => (
    is=>'ro',
    isa=>enum( [qw(src2trg trg2src)] ),
    default=>'trg2src',
    documentation=>'Default trg2src means alignment from <language,selector> to <source_language,source_selector> tree. src2trg means the opposite direction.',
);

sub process_zone {
    my ( $self, $zone ) = @_;
    my $source_zone = $zone->get_bundle()->get_zone( $self->source_language, $self->source_selector);
    my ($tree, $source_tree) = map {$_->get_tree($self->layer)} ($zone, $source_zone);
    
    my @source_nodes = $source_tree->get_descendants({ordered=>1});
    my @target_nodes = $tree->get_descendants({ordered=>1});
    
    my @alignments = (); 
    
    if ($self->alignment_direction eq 'src2trg') {
    	foreach my $sn (@source_nodes) {
    		my @an = $sn->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->language, $self->selector);
    		if (@an) {
    			map{push @alignments, ($sn->ord-1) . '-' . ($_->ord-1) }@an;
    		}
    	}
    }
    else {
    	foreach my $sn (@source_nodes) {
    		my @trg_nodes = grep {$_->is_aligned_to($sn, '^' . $self->alignment_type . '$')} $sn->get_referencing_nodes('alignment', $self->language, $self->selector);
    		if (@trg_nodes) {
    			map{push @alignments, ($sn->ord-1) . '-' . ($_->ord-1) }@trg_nodes;
    		}
    	}                	
    }
    if (scalar(@alignments) > 0) {
    	print { $self->_file_handle() } join(" ", @alignments) . "\n";
    }
    else { # empty line if no alignments found
    	print { $self->_file_handle() } "\n";
    }
}


1;

__END__

=head1 NAME

Treex::Block::Write::Alignments - Prints word alignment between trees

=head1 DESCRIPTION

The block prints the alignment between trees. The alignment format is compatible with the format used by the word aligners .

=head1 TODO

Possible alignments are not indicated anywhere at the moment .

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
 

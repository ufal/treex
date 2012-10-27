package Treex::Block::Read::Giza;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has to_selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );
has to_language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );
has layer => ( isa=>'Treex::Type::Layer', is=>'ro', default=> 'a');
has type => (isa=>'Str', is=>'ro', default=>'alignment', documentation=>'The alignment links will be stored with this type.');
has inverse => (isa=>'Bool', is=>'ro', default=>0, documentation=>'Inverse the direction of alignment. E.g. treat 3-5 in the input file as a link from node 5 to node 3');

has from => (
    isa           => 'Treex::Core::Files',
    is            => 'rw',
    coerce        => 1,
    required      => 1,
    handles       => [qw(current_filename file_number _set_file_number)],
    documentation => 'arrayref of filenames to be loaded, '
        . 'coerced from a space or comma separated list of filenames',
);

sub process_zone {
    my ($self, $zone, $bundleNo) = @_;
    my $to_zone = $zone->get_bundle()->get_zone($self->to_language, $self->to_selector);
    log_fatal("Bundle $bundleNo contains no zone (" . $self->to_language . ", " . $self->to_selector . ").") if !$to_zone;
    my ($tree, $to_tree) = map {$_->has_tree($self->layer) ? $_->get_tree($self->layer) : $_->create_tree($self->layer)} ($zone, $to_zone);
    my @nodes = $tree->get_descendants({ordered => 1});
    my @to_nodes = $to_tree->get_descendants({ordered => 1});
    my $line = $self->from->next_line() || return;
    #log_fatal 'Missing line in alignment file ' . $self->from->current_filename if !defined $line;

    foreach my $link (split /\s+/, $line) {
        log_fatal "Unexpected token '$link' in alignment line $line" if $link !~ /^[0-9]+-[0-9]+$/;
        my ($i_from, $i_to) = split /-/, $link;
        if ($self->inverse){
            ($i_from, $i_to) = ($i_to, $i_from);
        }
        my $n_from = $nodes[$i_from] or log_warn "Alignment index $i_from higher than number of nodes-1 in " . $tree->id;
        my $n_to   = $to_nodes[$i_to] or log_warn "Alignment index $i_to higher than number of nodes-1 in " . $to_tree->id;
        $n_from->add_aligned_node( $n_to, $self->type ) if $n_from && $n_to;
    }
    return 1;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::Read::Giza - add alignment links to a document

=head1 SYNOPSIS

 echo "Petr  má rád Prahu"  > cs.txt
 echo "Peter likes  Prague" > en.txt
 echo "0-0 1-1 2-1 3-2"     > ali.txt

 treex -s Read::AlignedSentences cs=cs.txt en=en.txt W2A::Tokenize\
          Read::Giza language=cs to_language=en from=ali.txt
 # Alignment is: Petr->Peter má->likes rád->likes Prahu->Prague
   
 treex Read::AlignedSentences cs=cs.txt en=en.txt W2A::Tokenize\
       Read::Giza language=en to_language=cs from=ali.txt inverse=1
 # Alignment is: Peter->Petr likes->má likes->rád Prague->Prahu

=head1 DESCRIPTION

Reads GIZA++ style alignments from a file (zero-based indices) and inserts them to an already existing document.

=head1 PARAMETERS

todo POD

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

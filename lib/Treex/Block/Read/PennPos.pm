package Treex::Block::Read::PennPos;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

has 'encode_punctuation_tags' => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
    documentation => 'Convert "(" tag to "-LRB-", etc.',
);

my %SUBSTITUTE = (
    '(' => '-LRB-',
    ')' => '-RRB-',
);

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;
    my $document = $self->new_document();
    
    # Sentence cannot end with a bracket
    $text =~ s/]\n//g;
    
    # Sentence cannot start with closing quotes or brackets
    $text =~ s{\n\n\s*(''/''|\)/\))}{\n$1}g;
    
    # Stories are separated by "=====" (38 symbols), which always marks a sentence boundary
    $text =~ s{^={10,}}{\n\n}g;
    
    my @sentences = split /\n\n/ms, $text;
    foreach my $sentence ( @sentences ) {
        next if $sentence =~ /^\s*$/;
        my @tokens = grep{/./ && !/^[][=]+$/} split /\s+/, $sentence;
        next if !@tokens;
        
        my $bundle = $document->create_bundle();
        my $zone   = $bundle->create_zone( $self->language, $self->selector );
        my $aroot  = $zone->create_atree();
        my $ord=1;
        foreach my $token (@tokens) {
            my $node = $aroot->create_child({ord=>$ord++});
            if ($token =~ s{/([^/]+$)}{}) {
                my $tag = $1;
                if ($self->encode_punctuation_tags){
                    $tag = $SUBSTITUTE{$tag} || $tag;
                }
                $node->set_tag($tag);
            } else {
                log_warn "Token without a tag: '$token'";
            }
            $node->set_form($token);
        }
        
        $zone->set_sentence( join ' ', map {$_->form} $aroot->get_children() );
    }
    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::PennPos

=head1 DESCRIPTION

Document reader for C<pos> format files from Penn TreeBank.
The files are loaded to the a-layer as a sequence of tokens.
The expected input looks like this:

 [ Pierre/NNP Vinken/NNP ]
 ,/, 
 [ 61/CD years/NNS ]
 old/JJ ,/, will/MD join/VB 
 [ the/DT board/NN ]
 as/IN 
 [ a/DT nonexecutive/JJ director/NN Nov./NNP 29/CD ]
 ./. 

The PennTB3 readme says:
I<"The square brackets surrounding phrases in the texts are the output
of a stochastic NP parser that is part of PARTS and are best ignored.">
Therefore, we ignore the brackets, but we use them as a clue
that no sentence can end with a bracket.
This heuristics helps us to recognize sentence boundaries,
which are not marked unambiguously in the C<pos> format.


=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

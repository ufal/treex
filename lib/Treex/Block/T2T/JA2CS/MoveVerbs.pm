package Treex::Block::T2T::JA2CS::MoveVerbs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $troot ) = @_;
    foreach my $tnode ( $troot->get_descendants ) {

        if (( $tnode->formeme || "" ) =~ /v:/ ) {
          my @children = grep { ($_->formeme || "") =~ /n:/ } $tnode->get_children( {ordered => 1} );
          next if (!@children);
          my $child = shift @children;
          $tnode->shift_after_node($child);
        }
    
    }

}

1;

=over

=item Treex::Block::T2T::JA2CS::MoveVerbs

Since Japanese language has subject-object-verb structure 
(in some cases it can be object-subject-verb) we apply this block to change
word order in the target Czech sentence (Czech is a subject-verb-object language).
Each verb is moved using simple heurictic:
verb is shifted to the beginning of the sentence, right after subject, if subject
is present. Otherwise, we shift the verb after first noun found anyway.

TODO: implement better heuristic


=back

=cut

=head1 AUTHORS

Dusan Varis

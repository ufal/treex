package Treex::Block::HamleDT::OrigFileSentToComment;
use utf8;
use open ':utf8';
use Moose;
extends 'Treex::Core::Block';

has 'last_loaded_from' => ( is => 'rw', isa => 'Str', default => '' );
has 'sent_in_file'     => ( is => 'rw', isa => 'Int', default => 0 );

#------------------------------------------------------------------------------
# Saves the input file name and sentence number in $bundle->wild->comment, to
# be printed in CoNLL-U. Note that this is different from the sentence id.
#------------------------------------------------------------------------------
sub process_atree
{
    my ($self, $root) = @_;
    # Add the name of the input file and the number of the sentence inside
    # the file as a comment that will be written in the CoNLL-U format.
    # (In any case, Write::CoNLLU will print the sentence id. But this additional
    # information is also very useful for debugging, as it ensures a user can
    # find the sentence in Tred.)
    my $bundle = $root->get_bundle();
    my $loaded_from = $bundle->get_document()->loaded_from(); # the full path to the input file
    my $file_stem = $bundle->get_document()->file_stem(); # this will be used in the comment
    if($loaded_from eq $self->last_loaded_from())
    {
        $self->set_sent_in_file($self->sent_in_file() + 1);
    }
    else
    {
        $self->set_last_loaded_from($loaded_from);
        $self->set_sent_in_file(1);
    }
    my $sent_in_file = $self->sent_in_file();
    my $comment = "orig_file_sentence $file_stem\#$sent_in_file";
    my @comments;
    if(defined($bundle->wild()->{comment}))
    {
        @comments = split(/\n/, $bundle->wild()->{comment});
    }
    if(!any {$_ eq $comment} (@comments))
    {
        push(@comments, $comment);
        $bundle->wild()->{comment} = join("\n", @comments);
    }
}



1;

=over

=item Treex::Block::HamleDT::OrigFileSentToComment

Figures out the name of the file the current sentence has been read from, and
the number of the sentence within that file. Saves both as the orig_sentence_file
comment, which will be printed when a CoNLL-U file is written. This will make
it easier to locate the Treex file and open it in TrEd if we need to debug the
conversion.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2016, 2025 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

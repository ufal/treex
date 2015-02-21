package Treex::Block::A2T::EN::QtHackFormeme;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;

    if ($tnode->formeme =~ /^v:/) {
        my @fake_subjects = grep { ($_->formeme // '') eq 'n:subj' }
            $tnode->get_echildren({following_only => 1});
        foreach my $fake_subject (@fake_subjects) {
            $fake_subject->set_formeme('n:obj');
        }
    }

    return;
}


1;

=head1 NAME 

Treex::Block::A2T::EN::QtHackFormeme

=head1 DESCRIPTION

Some hacks useful for QTLeap; aka domain adaptation o:-)

- relabel "subjects" that follow their parent verb as objects
(TODO: this can sometimes be correct, as in 'Blablabla, ' said Peter, so
let's account for that one day maybe...)

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


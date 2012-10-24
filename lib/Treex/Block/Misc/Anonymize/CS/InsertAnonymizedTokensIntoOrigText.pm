package Treex::Block::Misc::Anonymize::CS::InsertAnonymizedTokensIntoOrigText;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_document {
    my ( $self, $document ) = @_;

    my $orig_text = $document->get_zone('cs')->text;

    my @anodes = map {$_->get_zone('cs','anon')->get_atree->get_descendants} $document->get_bundles;

    my $new_text;
    my $lenght = length($orig_text);

    my $character_index = 0;
    my $anode_index = 0;

    while ( $character_index < $lenght ) {
        if ( substr($orig_text,$character_index,1) =~ /(\s)/ ) {
            $new_text .= $1;
            $character_index++;
#            print "shifting white space $1\n";
        }
        else {
            if ($anodes[$anode_index]->wild->{anonymized}) {
                $character_index += length($anodes[$anode_index]->wild->{origform});
#                print "replacing old form  ".$anodes[$anode_index]->wild->{origform}."--> ".$anodes[$anode_index]->form."\n";
            }
            else {
                $character_index += length($anodes[$anode_index]->form);
#                print "shifting form\n";
            }

            $new_text .= $anodes[$anode_index]->form;;
            $anode_index++;

        }
    }

    $document->create_zone('cs','anon');
    $document->get_zone('cs','anon')->set_text($new_text);

#    print "ORIGINAL TEXT: $orig_text\n\n";
#    print "ANONYMIZED TOKENS: ".join(" ",map {$_->form} @anodes)."\n";
#    print "NEW TEXT: $new_text\n";


}


1;


=head1 NAME

Treex::Block::Misc::Anonymize::CS::InsertAnonymizedTokensIntoOrigText

=head1 DESCRIPTION

Anonymized named entities are pushed into the original text,
while retaining all its white-space formatting.

=head1 AUTHOR

Zdeněk Žabokrtský

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

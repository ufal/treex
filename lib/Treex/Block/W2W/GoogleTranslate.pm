package Treex::Block::W2W::GoogleTranslate;

use utf8;
use Moose;
use Treex::Core::Common;
use LWP;
use Encode;
extends 'Treex::Core::Block';

has to_language => ( isa => 'Str', is => 'ro', required => 1 );
has to_selector => ( isa => 'Str', is => 'ro', default  => '' );


sub process_document {
    my ($self, $document) = @_;

    my @sentences;
    foreach my $bundle ($document->get_bundles) {
        my $sentence = $bundle->get_zone($self->language, $self->selector)->sentence;
        push @sentences, $sentence;
    }

    my $counter = 0;
    my $input_text = '';
    my $output_text = '';
    while (@sentences) {
        my $sentence = shift @sentences;
        $sentence =~ s/``/"/g;
        $sentence =~ s/''/"/g;
        $input_text .= "$sentence\n";
        $counter++;
        if ($counter % 50 == 0) {
            $output_text .= translate( $input_text, $self->language, $self->to_language ) if ($counter % 50 == 0);
            $input_text = '';
            sleep(2); 
        }
    }
    $output_text .= translate( $input_text, $self->language, $self->to_language ) if $input_text;
    @sentences = split(/\n/, $output_text);

    foreach my $bundle ($document->get_bundles) {
        my $zone = $bundle->get_or_create_zone($self->to_language, $self->to_selector);
        $zone->set_sentence(shift @sentences);
    }
}


sub translate {
    my ($text, $from, $to) = @_;
    my $ua = LWP::UserAgent->new;
    $ua->agent('Mozilla/5.0');

    my $response = $ua->post( "http://translate.google.com/translate_t",
                                [ 'text' => $text,
                                  'hl'   => 'en',
                                  'sl'   => $from,
                                  'tl'   => $to,
                                  'ie'   => 'UTF8'
                                ]
                            );
    log_fatal($response->status_line) if !$response->is_success;
    
    my $output = decode("utf8", $response->content);

    $output =~ tr/\n/ /;
    log_fatal("No output returned by GoogleTranslate") if $output !~ /<span id=result_box class="long_text">/;
    $output =~ s/^.+<span id=result_box class="long_text">//;
    $output =~ s/<\/span><\/div>.+$//;
    $output =~ s/<span[^>]+>//g;
    $output =~ s/<\/span>//g;
    $output =~ s/&quot;/"/g;
    $output =~ s/&amp;/&/g;
    $output =~ s/&#39;/'/g;
    $output =~ s/<br>/\n/g;
    return $output;
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::GoogleTranslate

=head1 DESCRIPTION

Uses GoogleTranslate to translate sentences from one zone to another.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

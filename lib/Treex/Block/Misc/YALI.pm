package Treex::Block::Misc::YALI;

use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

use Lingua::YALI::LanguageIdentifier;

has 'languages' => (is => 'ro', isa => 'ArrayRef[Str]', default => sub {return [qw/
    ara aze bel ben bos bul cat ces dan deu ell 
    eng epo est fas fin fra gle hbs heb hrv 
    hsb hun ita jpn lat lav lit mar mkd nld nor
    pol por ron rus slk slv spa sqi srp swe tel
    tur ukr uzb vie zho
/]});

sub process_document {
    my ($self, $doc) = @_;
    
    my $zone = $doc->get_zone($self->language, $self->selector);
    
    my $yali = Lingua::YALI::LanguageIdentifier->new();
    $yali->add_language(@{$self->languages});
    my $s = $zone->text;
    utf8::encode($s);
    my $yali_res = $yali->identify_string($s);
    $zone->set_attr('lang_id', $yali_res->[0][0]);
}

1;

=head1 NAME

Treex::Block::Misc::YALI;

=head1 DESCRIPTION

Language identification of a whole document zone by YALI.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

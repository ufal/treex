package Treex::Block::T2A::ES::AddAuxVerbModalTense;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddAuxVerbModalTense';

override '_build_gram2form' => sub {

    return {
        'ind' => {
            'sim' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'poder',
                'deb'     => 'deber',
            },
            'ant' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'poder',
                'deb'     => 'deber',
            },
            'post' => {
                ''     => '',
                'decl' => '',
                'poss' => 'poder',
                'deb'  => 'deber',
            },
        },
        'cdn' => {
            'sim' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'poder',
                'deb'     => 'deber',
            },
            'ant' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'poder',
                'deb'     => 'deber',
            },
            'post' => {
                ''     => '',
                'decl' => '',
                'poss' => 'poder',
                'deb'  => 'deber',
            },
        },
        'imp' => {
            'sim' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'poder',
                'deb'     => 'poder',
            },
            'ant' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'poder',
                'deb'     => 'deber',
            },
            'post' => {
                ''     => '',
                'decl' => '',
                'poss' => 'poder',
                'deb'  => 'deber',
            },
        },
    };
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::AddAuxVerbModalTense

=head1 DESCRIPTION

Add auxiliary expression for combined modality and tense.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::T2A::PT::AddAuxVerbModalTense;

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
                'poss_ep' => 'poder',
                'vol'     => 'querer',
                'deb'     => 'dever',
                'deb_ep'  => 'dever',
                'hrt'     => 'dever',
                'fac'     => 'poder / ser capaz (de)',
                'perm'    => 'poder',
                'perm_ep' => 'poder',
            },
            'ant' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'poder',
                'poss_ep' => 'poder',
                'vol'     => 'querer',
                'deb'     => 'dever',
                'deb_ep'  => 'dever',
                'hrt'     => 'dever',
                'fac'     => 'poder / ser capaz (de)',
                'perm_ep' => 'poder',
            },
            'post' => {
                ''     => '',
                'decl' => '',
                'poss' => 'poder',
                'vol'  => 'querer',
                'deb'  => 'ter de',
                'hrt'  => 'ter de',
                'fac'  => 'poder',
                'perm' => 'poder',
            },
        },
        'cdn' => {
            'sim' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'poder',
                'poss_ep' => 'poder',
                'vol'     => 'querer',
                'deb'     => 'dever',
                'deb_ep'  => 'dever',
                'hrt'     => 'dever',
                'fac'     => 'poder / ser capaz (de)',
                'perm'    => 'poder',
                'perm_ep' => 'poder',
            },
            'ant' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'poder',
                'poss_ep' => 'poder',
                'vol'     => 'querer',
                'deb'     => 'dever',
                'deb_ep'  => 'dever',
                'hrt'     => 'dever',
                'fac'     => 'poder / ser capaz (de)',
                'perm'    => 'poder',
                'perm_ep' => 'poder',
            },
            'post' => {
                ''     => '',
                'decl' => '',
                'poss' => 'poder',
                'vol'  => 'dever',
                'deb'  => 'dever',
                'hrt'  => 'dever',
                'fac'  => 'poder / ser capaz (de)',
                'perm' => 'poder',
            },
        },
    };
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::AddAuxVerbModalTense

=head1 DESCRIPTION

Portuguese modal verbs by {$verbmod}->{$tense}->{$deontmod}

=head1 AUTHORS

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.





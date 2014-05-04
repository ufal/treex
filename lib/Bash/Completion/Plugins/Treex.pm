package Bash::Completion::Plugins::Treex;
use strict;
use warnings;
use parent 'Bash::Completion::Plugin';
use Bash::Completion::Utils qw( command_in_path match_perl_modules prefix_match );
use List::MoreUtils qw( any );
use Moose (); #instead of use Class::MOP::Class;

my @general_options = qw(
 -d --dump_scenario
    --dump_required_files
 -e --error_level
 -h --help
 -L --language
 -p --parallel
 -q --quiet
 -s --save
 -S --selector
 -t --tokenize
 -v --version
    --watch
);

my @parallel_options = qw(
    --cache
    --cleanup
 -E --forward_error_level
 -j --jobs
    --local
 -m --memory
    --name
    --outdir
    --priority
    --qsub
    --survive
    --workdir
);

sub generate_bash_setup { return [qw( nospace default )]; }

sub should_activate { return [grep { command_in_path($_) } ('treex')]; }

# Block attributes which are not supposed to be used as parameters
my %nonparams = map {("$_=" => 1)} (qw(consumer doc_number jobindex jobs outdir));

sub get_block_parameters{
    my ($block_name) = @_;
    return if !$block_name || !eval "require $block_name";
    my $meta = Class::MOP::Class->initialize($block_name);
    return grep {!/^_/ && !$nonparams{$_}} map {$_->name."="} $meta->get_all_attributes;
}

sub complete {
    my ($self, $req) = @_;
    my @c;
    my $word = $req->word;
    my @args = $req->args;
    my $last = $args[$word ? -2 : -1] || 0;
    $last = ($last =~ /::/) ? "Treex::Block::$last" : 0;

    if ($word eq '') {
        @c = get_block_parameters($last);
        my @blocks = match_perl_modules('Treex::Block::');
        if (@c){
            print STDERR "\nBlocks:\n" . join("\t", @blocks) . "\n\nParameters of $last:";
        } else {
            @c = @blocks;
        }
    }
    elsif ($word =~ /^-/) {
        @c = prefix_match($word, @general_options);
        if (any {/^-(p|-parallel)/} @args){
            push @c, prefix_match($word, @parallel_options);
        }
    }
    elsif ($word =~ /=/) {
        # When no suggestions are given for parameter values,
        # default Bash (filename) completion is used.
    }
    else {
        @c = prefix_match($word, get_block_parameters($last));
        push @c, match_perl_modules("Treex::Block::$word");
    }

    return $req->candidates(map {/[:=]$/ ? $_ : "$_ "} @c);
}

1;

__END__


=encoding utf-8

=head1 NAME

Bash::Completion::Plugins::Treex - Bash completion for treex

=head1 SYNOPSIS
 
 # In Bash, press TAB to auto-complete treex commands
 $ treex A
 A2A::    A2N::    A2P::    A2T::    A2W::    Align::

 $ ftreex Read::Sentences 
 Blocks:
 W2W::   Read::  A2W::   T2A::   Tutorial::  Misc:: ...
 
 Parameters of Treex::Block::Read::Sentences:
 encoding=    is_one_doc_per_file=  merge_files=   skip_finished=
 file_stem=   language=             selector=             
 from=        lines_per_doc=        skip_empty=
 
=head1 DESCRIPTION

L<Bash::Completion> profile for C<treex>.

Simply add this line to your C<.bashrc> file:

 source `perldoc -l setup-bash-complete`

or run it manually in a bash session.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

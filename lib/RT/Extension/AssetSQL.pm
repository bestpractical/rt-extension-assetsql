use strict;
use warnings;
package RT::Extension::AssetSQL;
use 5.010_001;

our $VERSION = '0.01';

require RT::Extension::AssetSQL::Assets;

RT->AddStyleSheets("assetsql.css");

sub RT::Interface::Web::QueryBuilder::Tree::GetReferencedCatalogs {
    my $self = shift;

    my $catalogs = {};

    $self->traverse(
        sub {
            my $node = shift;

            return if $node->isRoot;
            return unless $node->isLeaf;

            my $clause = $node->getNodeValue();
            return unless $clause->{ Key } eq 'Catalog';
            return unless $clause->{ Op } eq '=';

            $catalogs->{ $clause->{ RawValue } } = 1;
        }
    );

    return $catalogs;
}

sub RT::Interface::Web::QueryBuilder::Tree::ParseAssetSQL {
    my $self = shift;
    my %args = (
        Query       => '',
        CurrentUser => '',    #XXX: Hack
        @_
    );
    my $string = $args{ 'Query' };

    my @results;

    my %field = %{ RT::Assets->new( $args{ 'CurrentUser' } )->FIELDS };
    my %lcfield = map { ( lc( $_ ) => $_ ) } keys %field;

    my $node = $self;

    my %callback;
    $callback{ 'OpenParen' } = sub {
        $node = RT::Interface::Web::QueryBuilder::Tree->new( 'AND', $node );
    };
    $callback{ 'CloseParen' } = sub { $node = $node->getParent };
    $callback{ 'EntryAggregator' } = sub { $node->setNodeValue( $_[ 0 ] ) };
    $callback{ 'Condition' } = sub {
        my ( $key, $op, $value ) = @_;
        my $rawvalue = $value;

        my ( $main_key ) = split /[.]/, $key;

        my $class;
        if ( exists $lcfield{ lc $main_key } ) {
            $key =~ s/^[^.]+/ $lcfield{ lc $main_key } /e;
            ( $main_key ) = split /[.]/, $key;    # make the case right
            $class = $field{ $main_key }->[ 0 ];
        }
        unless ( $class ) {
            push @results, [ $args{ 'CurrentUser' }->loc( "Unknown field: [_1]", $key ), -1 ];
        }

        if ( lc $op eq 'is' || lc $op eq 'is not' ) {
            $value = 'NULL';                      # just fix possible mistakes here
        }
        elsif ( $value !~ /^[+-]?[0-9]+$/ ) {
            $value =~ s/(['\\])/\\$1/g;
            $value = "'$value'";
        }

        if ( $key =~ s/(['\\])/\\$1/g or $key =~ /[^{}\w\.]/ ) {
            $key = "'$key'";
        }

        my $clause = { Key => $key, Op => $op, Value => $value, RawValue => $rawvalue };
        $node->addChild( RT::Interface::Web::QueryBuilder::Tree->new( $clause ) );
    };
    $callback{ 'Error' } = sub { push @results, @_ };

    require RT::SQL;
    RT::SQL::Parse( $string, \%callback );
    return @results;
}

=head1 NAME

RT-Extension-AssetSQL - SQL search builder for Assets

=cut

=head1 INSTALLATION

RT-Extension-AssetSQL requires version RT 4.4.0 or later.

=over

=item perl Makefile.PL

=item make

=item make install

This step may require root permissions.

=item Patch your RT

AssetSQL requires a small patch to work on versions of RT prior to 4.4.2.
To patch such older versions of RT, run:

    patch -d /opt/rt4 -p1 < patches/rt-4.4.0-4.4.1.patch

RT versions 4.4.2 and later already contain the above patch.

All versions of RT require the following patch for AssetSQL support:

    patch -d /opt/rt4 -p1 < patches/assetsql.patch

You must apply both patches if you're on RT 4.4.0 or 4.4.1.

=item Edit your /opt/rt4/etc/RT_SiteConfig.pm

Add this line:

    Plugin( "RT::Extension::AssetSQL" );

=item Clear your mason cache

    rm -rf /opt/rt4/var/mason_data/obj

=item Restart your webserver

=back

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=head1 BUGS

All bugs should be reported via email to

    L<bug-RT-Extension-AssetSQL@rt.cpan.org|mailto:bug-RT-Extension-AssetSQL@rt.cpan.org>

or via the web at

    L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-AssetSQL>.

=head1 COPYRIGHT

This extension is Copyright (C) 2016 Best Practical Solutions, LLC.

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

1;

# Dvanáctka

Mobile application for city district Prague 12. It includes iOS and Android client app and includes server scripts for gathering the data and providing them to the client apps.

It is possible to adapt the app for any other city or village. The apps itself contains no hard-coded links to Prague 12, the data source definitions can be easily altered in [appDefinition.json](appDefinition.json). You can select which tiles (data sources) to show or hide, or define completely new ones there.

## License

The source code is provided under [GNU General Public License
version 3](https://www.gnu.org/licenses/gpl.html).

Please contact us in case you would like to purchase the commercial license enabling to use the cloned repository without providing your app source code.

### Why open-sourced municipality app?

Cities often end up in software solutions that lock them to products and services provided by one company (i.e. vendor lock-in). Having the app with open source code can enable municipality to maintain control over the source code and still enable paid contractors to improve the product.

## Contributing

Please contact us using the contact form at [dvanactka.info](https://dvanactka.info) before changing or implementing your ideas.

The source code is separated into several main folders:

* `Android/` - app for Android OS.
* `iOS/` - app for iPhone and iPad.
* `server/` - scripts running on some server. Their goal is to gather the data parse it, and store it in common format recognized by all versions of client apps. These scripts are specific to the municipality the app is running for.
* `test_files/` - manually maintained data about the municipality. Most of these files are stored on the server, and also shipped with the apps as the initial data used in case the app cannot connect to the server.
* `art/` - icons and general program graphics.

We use the current versions of Android Studio and Xcode to compile and edit the projects.

### Updating the data files about Prague 12

It is also possible (and welcomed) to update the information about the shops, restaurants and locations in Prague 12. Everything is stored in a few files in [JSON format](https://en.wikipedia.org/wiki/JSON).

* `test_files/p12kultpamatky.json` - monuments, interesting places, memorable trees
* `test_files/p12shops.json` - shops, restaurants, local services
* `test_files/sos.json` - basic information, help contacts, pharmacies, public toilets
* `test_files/spolkyList.json` - local associations, sport clubs, family centers

Please verify the JSON is valid in [JSONLint](https://jsonlint.com) before submitting your changes.

## Future

There are several possibilities we can imagine the project is further developed.

1. There will be list of municipalities inside one mobile app, and user is asked to select his/her municipality. Thus there will be only one general app for all those municipalities in app stores.

1. Each municipality clones the repository, but continues to contribute into the original one.

Last but not least. As people are often reluctant to install apps into their phones, **it would be nice to have some web frontend** to present the collected map data, as the data files often contain the details that cannot be found anywhere else on the Internet.

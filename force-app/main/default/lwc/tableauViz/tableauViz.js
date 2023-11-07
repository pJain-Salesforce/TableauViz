/* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* tableauViz : Modified Tableau Viz LWC to support advanced filtering
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Nathan Shulman  nathan.shulman@bofa.com
* @modifiedBy     Nathan Shulman  nathan.shulman@bofa.com
* @maintainedBy   Nathan Shulman  nathan.shulman@bofa.com
* @version        1.1
* @created        2023-06-14
* @modified       2023-07-14
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @changes
* 2023-07-14   Added load error message
* 2023-06-14   Initial Version
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
* Additional Info:
*
* This is a modified version of the Tableau Dashboard Viz component (open source) and
* supports filtering by any field, traversing relationships, multi-select picklists,
* and filtering on child record fields
*/
import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import tableauJSAPI from '@salesforce/resourceUrl/TableauJSAPI';
import getFilters from '@salesforce/apex/TableauVizController.getFiltersByRecordId';

import templateMain from './tableauViz.html';
import templateError from './tableauVizError.html';

export default class TableauViz extends LightningElement {
    _vizDefinitionDevName;
    _vizUrl;
    vizLoading = false;
    vizLoadingIssue = false;
    @api objectApiName;
    @api recordId;
    @api height;
    @api tabAdvancedFilter;

    // Used for filter definition
    @api
    get sfVizDefinition() {
        return this._vizDefinitionDevName;
    }
    set sfVizDefinition (value) {
        this._vizDefinitionDevName = value;
        // force rerender when changed
        this.renderViz();
    }

    @api
    get vizUrl() {
        return this._vizUrl;
    }
    set vizUrl(value) {
        this._vizUrl = value;
        // force rerender when changed
        this.renderViz();
    }

    viz;
    workbook;
    activeSheet;
    advancedFilterValue;
    errorMessage;
    isLibLoaded = false;

    // Use hashnames for private fields when that is accepted
    _showTabs = false;
    _showToolbar = false;
    _filterOnRecordId = false;

    // In JavaScript, there are six falsy values:
    // false, 0, '', null, undefined, and NaN. Everything else is truthy.
    // LWC can sometimes return 'false' as a string and we need to treat it as false
    // the !! operator converts any object to Boolean type
    static booleanNormalize(val) {
        if (typeof val == 'string' && val.toLowerCase() === 'false') {
            return false;
        }
        return !!val;
    }

    @api
    get showTabs() {
        return this._showTabs;
    }

    set showTabs(val) {
        this._showTabs = TableauViz.booleanNormalize(val);
    }

    @api
    get showToolbar() {
        return this._showToolbar;
    }

    set showToolbar(val) {
        this._showToolbar = TableauViz.booleanNormalize(val);
    }

    @api
    get filterOnRecordId() {
        return this._filterOnRecordId;
    }

    set filterOnRecordId(val) {
        this._filterOnRecordId = TableauViz.booleanNormalize(val);
    }

    async connectedCallback() {
        const self = this;
        await loadScript(this, tableauJSAPI);
        this.isLibLoaded = true;
        window.addEventListener('message', (e) => {            
            if (typeof e.data === 'string' && e.data.substring(0,17) === 'tableau.listening') {
                self.vizLoading = true;
            }
        }, false);
        this.renderViz();
    }

    renderedCallback() {
        this.renderViz();
    }

    async renderViz() {
        // Halt rendering if inputs are invalid or if there's an error
        // or if the URL hasn't been set yet
        if (!this.vizUrl || !this.validateInputs() || this.errorMessage) {
            return;
        }

        // Halt rendering if lib is not loaded
        if (!this.isLibLoaded) {
            return;
        }

        const containerDiv = this.template.querySelector(
            'div.tabVizPlaceholder'
        );

        // Configure viz URL
        const vizToLoad = new URL(this.vizUrl);
        this.setVizDimensions(vizToLoad, containerDiv);
        this.setVizFilters(vizToLoad);
        TableauViz.checkForMobileApp(vizToLoad, window.navigator.userAgent);
        const vizURLString = vizToLoad.toString();

        // Set viz Options
        const options = {
            hideTabs: false, // !this.showTabs,
            toolbarPosition: 'Top',
            hideToolbar: false, // !this.showToolbar,
            height: `${this.height}px`,
            width: '100%',
            onFirstInteractive: () => {
                this.vizLoadingIssue = false;
                this.vizLoading = true;
                this.workbook = this.viz.getWorkbook();
                this.activeSheet = this.workbook.getActiveSheet();
                this.vizLoadedHandler();
            }
        };

        const self = this;
        // eslint-disable-next-line no-undef
        try {
            self.viz = new tableau.Viz(containerDiv, vizURLString, options);
            setTimeout(() => {
                if (!self.vizLoading) {
                    self.vizLoadingIssue = true;
                }
            }, 5000);
        } catch (e) {
            this.errorMessage = e.message;
        }


    }

    // Do this after the viz is loaded
    async vizLoadedHandler() {
        const filterResult = await getFilters({vizDeveloperName: this._vizDefinitionDevName, recordId: this.recordId});
        const filters = filterResult.filters;
        if (filterResult.worksheet) {
            await this.workbook.activateSheetAsync(filterResult.worksheet);
            // update cached active sheet
            this.activeSheet = this.workbook.getActiveSheet();
        }

        // Loop through property names and set the values
        // Property names are the filter names
        for (const filter of filters) {
            // may need await here
            const filterFunction = filter.selectionOnly ? 'selectMarksAsync' : 'applyFilterAsync';
            const filterMode = filter.selectionOnly ? tableau.SelectionUpdateType.REPLACE : tableau.FilterUpdateType.REPLACE;
            this.activeSheet[filterFunction](
                filter.name,
                filter.values,
                filterMode);
        }
    }

    render() {
        if (this.errorMessage) {
            return templateError;
        }
        return templateMain;
    }

    validateInputs() {
        // Validate viz url
        try {
            const u = new URL(this.vizUrl);
            if (u.protocol !== 'https:') {
                throw Error(
                    'Invalid URL. Make sure the link to the Tableau view is using HTTPS.'
                );
            }

            if (u.toString().replace(u.origin, '').startsWith('/#/')) {
                throw Error(
                    "Invalid URL. Enter the link for a Tableau view. Click Copy Link to copy the URL from the Share View dialog box in Tableau. The link for the Tableau view must not include a '#' after the name of the server."
                );
            }
        } catch (error) {
            this.errorMessage = error.message ? error.message : 'Invalid URL';
            return true;
        }
        return true;
    }

    // Height is set by the user
    // Width is based on the containerDiv to which the viz is added
    // The ':size' parameter is added to the url to communicate this
    setVizDimensions(vizToLoad, containerDiv) {
        containerDiv.style.height = `${this.height}px`;
        const vizWidth = containerDiv.offsetWidth;
        vizToLoad.searchParams.append(':size', `${vizWidth},${this.height}`);
    }

    setVizFilters(vizToLoad) {
        // In context filtering
        if (this.filterOnRecordId === true && this.objectApiName) {
            const filterNameTab = `${this.objectApiName} ID`;
            vizToLoad.searchParams.append(filterNameTab, this.recordId);
        }

        // Additional Filtering
        if (this.tabAdvancedFilter && this.advancedFilterValue) {
            vizToLoad.searchParams.append(
                this.tabAdvancedFilter,
                this.advancedFilterValue
            );
        }
    }

    static checkForMobileApp(vizToLoad, userAgent) {
        const mobileRegex = /SalesforceMobileSDK/g;
        if (!mobileRegex.test(userAgent)) {
            return;
        }

        const deviceIdRegex = /uid_([\w|-]+)/g;
        const deviceNameRegex = /(iPhone|Android|iPad)/g;

        const deviceIdMatches = deviceIdRegex.exec(userAgent);
        const deviceId =
            deviceIdMatches == null
                ? TableauViz.generateRandomDeviceId()
                : deviceIdMatches[1];
        const deviceNameMatches = deviceNameRegex.exec(userAgent);
        const deviceName =
            deviceNameMatches == null
                ? 'SFMobileApp'
                : `SFMobileApp_${deviceNameMatches[1]}`;

        vizToLoad.searchParams.append(':use_rt', 'y');
        vizToLoad.searchParams.append(':client_id', 'TableauVizLWC');
        vizToLoad.searchParams.append(':device_id', deviceId);
        vizToLoad.searchParams.append(':device_name', deviceName);
    }

    /* ***********************
     * This function just needs to generate a random id so that if the user-agent for this mobile device
     * doesn't contain a uid_ field, we can have a random id that is not likely to collide if the same user logs
     * in to SF Mobile from a different mobile device that also doesn't have a uid_ field.
     * ***********************/
    static generateRandomDeviceId() {
        function getRandomSymbol(symbol) {
            var array;

            if (symbol === 'y') {
                array = ['8', '9', 'a', 'b'];
                return array[Math.floor(Math.random() * array.length)];
            }

            array = new Uint8Array(1);
            window.crypto.getRandomValues(array);
            return (array[0] % 16).toString(16);
        }

        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(
            /[xy]/g,
            getRandomSymbol
        );
    }
}